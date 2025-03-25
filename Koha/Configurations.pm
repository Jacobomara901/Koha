package Koha::Configurations;

# Copyright Theke Solutions 2020
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use Koha::Database;
use Koha::Configuration;
use Koha::ConfigurationGroups;

use base qw(Koha::Objects);

=head1 NAME

Koha::Configurations - Koha Configurations Object set class

=head1 API

=head2 Class Methods

=cut

=head3 get_effective_config

    my $result = Koha::Configurations->get_effective_config({
        name => 'setting_name',
        library_id => $library_id,   # optional
        category_id => $category_id, # optional
        item_type => $item_type,     # optional
        with_metadata => 1           # optional, defaults to 0
    });

Get the most specific configuration for the given parameters.
The function tries to find the most appropriate configuration based on
the specificity level (library, category, item_type) and falls back to
global if no specific configuration exists.

Parameters:
  - name: Required. The name of the configuration setting.
  - library_id: Optional. Library code for library-specific configuration.
  - category_id: Optional. Patron category code for category-specific configuration.
  - item_type: Optional. Item type code for item-specific configuration.
  - with_metadata: Optional. If set to 1, returns a hashref with additional context. Default: 0.

Returns:
  - If with_metadata = 0: The configuration object or undef if not found.
  - If with_metadata = 1: A hashref containing:
      - config: the Koha::Configuration object
      - level: the level at which it was found ('global', 'library', 'category', 'item_type')
      - used_library_id: the library_id of the config that was applied (if applicable)
      - used_category_id: the category_id of the config that was applied (if applicable)
      - used_item_type: the item_type of the config that was applied (if applicable)

=cut

sub get_effective_config {
    my ( $self, $params ) = @_;

    my $name = $params->{name};
    Koha::Exceptions::MissingParameter->throw(
        "Required parameter 'name' missing")
      unless $name;

    # Default other params and ensure consistent with_metadata behavior
    my $with_metadata = exists $params->{with_metadata} ? $params->{with_metadata} : 0;  # Default to 0 unless explicitly set
    my $category_id   = $params->{category_id} // undef;
    my $library_id    = $params->{library_id}  // undef;
    my $item_type     = $params->{item_type}   // undef;

    # Build search conditions for this name
    my $base_condition = { name => $name };
    my $config;

    # Try library-specific first
    if ($library_id) {
        $config = $self->search({
            %$base_condition,
            library_id => $library_id,
            category_id => undef,
            item_type => undef,
        })->single;

        if ($config) {
            return $with_metadata ? {
                config => $config,
                level => 'library',
                used_library_id => $library_id,
                used_category_id => undef,
                used_item_type => undef
            } : $config;
        }
    }

    # Try category-specific next
    if ($category_id && !$config) {
        $config = $self->search({
            %$base_condition,
            library_id => undef,
            category_id => $category_id,
            item_type => undef,
        })->single;

        if ($config) {
            # Found a category-specific match
            my $result = $with_metadata
                ? {
                    config => $config,
                    level => 'category',
                    used_library_id => undef,
                    used_category_id => $config->category_id,
                    used_item_type => undef
                }
                : $config;
            return $result;
        }
    }

    # Try item_type-specific next
    if ($item_type && !$config) {
        $config = $self->search({
            %$base_condition,
            library_id => undef,
            category_id => undef,
            item_type => $item_type,
        })->single;

        if ($config) {
            # Found an item_type-specific match
            my $result = $with_metadata
                ? {
                    config => $config,
                    level => 'item_type',
                    used_library_id => undef,
                    used_category_id => undef,
                    used_item_type => $config->item_type
                }
                : $config;
            return $result;
        }
    }

    # Finally, try global config
    $config = $self->search({
        %$base_condition,
        library_id => undef,
        category_id => undef,
        item_type => undef,
    })->single;

    if ($config) {
        # Found a global match
        my $result = $with_metadata
            ? {
                config => $config,
                level => 'global',
                used_library_id => undef,
                used_category_id => undef,
                used_item_type => undef
            }
            : $config;
        return $result;
    }

    # No match found
    return undef;
}

=head3 by_group

    my $configs = Koha::Configurations->by_group($group_identifier);

Returns all configuration entries belonging to a specific configuration group,
regardless of their scope (global, library, category, or item type).

Parameters:
  - $group_identifier: Either a bit number (integer) or a flag name (string) that identifies the group

Returns:
  - A Koha::Configurations object containing all configurations for the specified group
  - undef if the group identifier is invalid

=cut

sub by_group {
    my ($self, $group_identifier) = @_;
    
    my $bit;
    if (defined $group_identifier) {
        # Check if the identifier is a bit (number) or a flag (string)
        if ($group_identifier =~ /^\d+$/) {
            # It's a number, use directly as bit
            $bit = $group_identifier;
        } else {
            # It's a string, look up as flag
            my $group = Koha::ConfigurationGroups->find_by_flag($group_identifier);
            return unless $group;
            $bit = $group->bit;
        }
    } else {
        return;
    }
    
    return $self->search({ configuration_group_bit => $bit });
}

=head3 group_setting_names

    my $names = Koha::Configurations->group_setting_names($group_identifier);

Returns a list of distinct setting names that belong to a specific configuration group.
This ignores the scope (global, library, category, item type) and returns only unique names.

Parameters:
  - $group_identifier: Either a bit number (integer) or a flag name (string) that identifies the group

Returns:
  - An arrayref of strings containing the distinct setting names for this group
  - undef if the group identifier is invalid

=cut

sub group_setting_names {
    my ($self, $group_identifier) = @_;
    
    my $bit;
    if (defined $group_identifier) {
        # Check if the identifier is a bit (number) or a flag (string)
        if ($group_identifier =~ /^\d+$/) {
            # It's a number, use directly as bit
            $bit = $group_identifier;
        } else {
            # It's a string, look up as flag
            my $group = Koha::ConfigurationGroups->find_by_flag($group_identifier);
            return unless $group;
            $bit = $group->bit;
        }
    } else {
        return;
    }

    # Use DBIx::Class to get distinct names
    my $rs = $self->_resultset->search(
        { configuration_group_bit => $bit },
        {
            columns  => ['name'],
            distinct => 1,
            order_by => 'name'
        }
    );
    
    my @names;
    while (my $row = $rs->next) {
        push @names, $row->name;
    }
    
    return \@names;
}

=head3 _type

=cut

sub _type {
    return 'Configuration';

}

=head3 object_class

=cut

sub object_class {
    return 'Koha::Configuration';
}

1;
