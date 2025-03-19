package Koha::Configuration;

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
use Koha::Exceptions;

use base qw(Koha::Object);

use Koha::Libraries;
use Koha::Patron::Categories;
use Koha::ItemTypes;

=head1 NAME

Koha::Configuration - Koha Configuration object class

=head1 API

=head2 Class methods

=cut

=head3 library

Returns a Koha::Library object if the configuration entry is tied to a specific library.

=cut

sub library {
    my ($self) = @_;

    my $library_rs = $self->_result->library;
    return unless $library_rs;
    return Koha::Library->_new_from_dbic( $library_rs );
}

=head3 category

Returns a Koha::Patron::Category if the configuration entry is tied to a specific category.

=cut

sub category {
    my ($self) = @_;

    my $category_rs = $self->_result->category;
    return unless $category_rs;
    return Koha::Patron::Category->_new_from_dbic( $category_rs );
}

=head3 item_type

Returns a Koha::ItemType if the configuration entry is tied to a specific item type.

=cut

sub item_type {
    my ($self) = @_;

    my $item_type_rs = $self->_result->item_type;
    return unless $item_type_rs;
    return Koha::ItemType->_new_from_dbic( $item_type_rs );
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'Configuration';
}

=head3 store

Overloaded I<store> method that enforces configuration uniqueness constraints.

This method ensures:
- Each configuration can only have one specificity level (library, category or item type)
- Each configuration name has at most one entry for a given specificity level
- No duplicate configurations are created

=cut

sub store {
    my $self = shift;

    # Validate the specificity level - only one can be specified
    my $specificity_count = 0;
    $specificity_count++ if $self->library_id && length $self->library_id;
    $specificity_count++ if $self->category_id && length $self->category_id;
    $specificity_count++ if $self->item_type && length($self->item_type);

    if ($specificity_count > 1) {
        Koha::Exceptions::BadParameter->throw(
            error => "Configuration must have at most one specificity level (library, category, or item type)."
        );
    }

    # Prepare the search parameters to check for uniqueness
    my $search_params = {
        name => $self->name,
        library_id => undef,
        category_id => undef,
        item_type => undef
    };

    # Handle item_type being passed as an object (get the actual code)
    if (ref($self->item_type)) {
        $search_params->{item_type} = $self->item_type->itemtype;
    } elsif ($self->item_type && length $self->item_type) {
        $search_params->{item_type} = $self->item_type;
    }

    # Override NULL values with actual values if present
    $search_params->{library_id} = $self->library_id if $self->library_id && length $self->library_id;
    $search_params->{category_id} = $self->category_id if $self->category_id && length $self->category_id;

    # Uses Koha::Configurations->search() which leverages DBIx::Class
    my $existing = Koha::Configurations->search($search_params);

    # Proper chaining of DBIx::Class queries
    if ($self->in_storage) {
        $existing = $existing->search({ id => { '!=' => $self->id } });
    }

    # Throw exception if a duplicate would be created
    if ($existing->count > 0) {
        Koha::Exceptions::DuplicateObject->throw(
            error => "A configuration for '$search_params->{name}' with the same scope already exists."
        );
    }

    # Calls parent's (Koha::Object) store method which uses DBIx::Class
    return $self->SUPER::store(@_);
}

1;
