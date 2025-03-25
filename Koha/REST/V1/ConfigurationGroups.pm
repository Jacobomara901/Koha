package Koha::REST::V1::ConfigurationGroups;

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

use Mojo::Base 'Mojolicious::Controller';

use Koha::ConfigurationGroup;
use Koha::ConfigurationGroups;

use Try::Tiny qw( catch try );

=head1 API

=head2 Methods

=head3 list

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $configuration_groups = $c->objects->search( Koha::ConfigurationGroups->new );
        return $c->render( status => 200, openapi => $configuration_groups );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 get

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $identifier = $c->param('group_identifier');
        my $group;
        
        # Check if the identifier is numeric (bit) or a string (flag)
        if ($identifier =~ /^\d+$/) {
            # It's a number, look up by bit
            $group = Koha::ConfigurationGroups->find($identifier);
        } else {
            # It's a string, look up by flag
            $group = Koha::ConfigurationGroups->find_by_flag($identifier);
        }
        
        return $c->render_resource_not_found("Configuration group")
            unless $group;

        return $c->render( status => 200, openapi => $c->objects->to_api($group), );
    } catch {
        $c->unhandled_exception($_);
    };
}

1;
