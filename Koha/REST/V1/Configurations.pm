package Koha::REST::V1::Configurations;

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

use Koha::Configuration;
use Koha::Configurations;
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
        my $configurations = $c->objects->search( Koha::Configurations->new );
        return $c->render( status => 200, openapi => $configurations );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 get

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $configuration = Koha::Configurations->find( $c->param('configuration_id') );
        return $c->render_resource_not_found("Configuration")
            unless $configuration;

        return $c->render( status => 200, openapi => $c->objects->to_api($configuration), );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 add

=cut

sub add {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $configuration = Koha::Configuration->new_from_api( $c->req->json );
        $configuration->store;
        $c->res->headers->location( $c->req->url->to_string . '/' . $configuration->id );
        return $c->render(
            status  => 201,
            openapi => $c->objects->to_api($configuration),
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 update

=cut

sub update {
    my $c = shift->openapi->valid_input or return;

    my $configuration = Koha::Configurations->find( $c->param('configuration_id') );

    return $c->render_resource_not_found("Configuration")
        unless $configuration;

    return try {
        $configuration->set_from_api( $c->req->json );
        $configuration->store();
        return $c->render( status => 200, openapi => $c->objects->to_api($configuration), );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 delete

=cut

sub delete {
    my $c = shift->openapi->valid_input or return;

    my $configuration = Koha::Configurations->find( $c->param('configuration_id') );

    return $c->render_resource_not_found("Configuration")
        unless $configuration;

    return try {
        $configuration->delete;
        return $c->render_resource_deleted;
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 get_effective

=cut

sub get_effective {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $name = $c->param('name');
        my $library_id = $c->param('library_id') // undef;
        my $category_id = $c->param('category_id') // undef;
        my $item_type = $c->param('item_type') // undef;
        my $with_metadata = $c->param('with_metadata') // 0;

        my $result = Koha::Configurations->get_effective_config({
            name => $name,
            library_id => $library_id,
            category_id => $category_id,
            item_type => $item_type,
            with_metadata => $with_metadata
        });

        return $c->render_resource_not_found("Configuration")
            unless $result;

        if ($with_metadata) {
            # If with_metadata is true, we already have a hashref with metadata
            return $c->render( status => 200, openapi => $result );
        } else {
            # If with_metadata is false, result is a Koha::Configuration object
            return $c->render( status => 200, openapi => $c->objects->to_api($result) );
        }
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 group_setting_names

=cut

sub group_setting_names {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $group_identifier = $c->param('group_identifier');
        my $names = Koha::Configurations->group_setting_names($group_identifier);

        return $c->render_resource_not_found("Configuration group")
            unless $names;

        return $c->render( status => 200, openapi => $names );
    } catch {
        $c->unhandled_exception($_);
    };
}

1;
