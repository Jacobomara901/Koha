package Koha::REST::V1::DisplayItems;

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

use Koha::DisplayItem;
use Koha::DisplayItems;

use Try::Tiny    qw( catch try );
use Scalar::Util qw( blessed );

=head1 API

=head2 Methods

=head3 list

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $displayitems = $c->objects->search( Koha::DisplayItems->new );
        return $c->render( status => 200, openapi => $displayitems );
    } catch {
        $c->unhandled_exception($_);
    };

}

=head3 get

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $displayitem = Koha::DisplayItems->find(
            {
                display_item_id => $c->param('display_item_id'),
                display_id      => $c->param('display_id'),
                itemnumber      => $c->param('item_id')
            }
        );
        return $c->render_resource_not_found("Display item")
            unless $displayitem;

        return $c->render( status => 200, openapi => $c->objects->to_api($displayitem), );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 add

=cut

sub add {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $displayitem = Koha::DisplayItem->new_from_api( $c->req->json );
        $displayitem->store;
        $c->res->headers->location(
            $c->req->url->to_string . '/' . $displayitem->display_id . '/' . $displayitem->itemnumber );
        return $c->render(
            status  => 201,
            openapi => $c->objects->to_api($displayitem),
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 update

=cut

sub update {
    my $c = shift->openapi->valid_input or return;

    my $displayitem = Koha::DisplayItems->find(
        {
            display_item_id => $c->param('display_item_id'),
            display_id      => $c->param('display_id'),
            itemnumber      => $c->param('item_id')
        }
    );

    return $c->render_resource_not_found("Display item")
        unless $displayitem;

    return try {
        $displayitem->set_from_api( $c->req->json );
        $displayitem->store();
        return $c->render( status => 200, openapi => $c->objects->to_api($displayitem), );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 delete

=cut

sub delete {
    my $c = shift->openapi->valid_input or return;

    my $displayitem = Koha::DisplayItems->find(
        {
            display_item_id => $c->param('display_item_id'),
            display_id      => $c->param('display_id'),
            itemnumber      => $c->param('item_id')
        }
    );

    return $c->render_resource_not_found("Display item")
        unless $displayitem;

    return try {
        $displayitem->delete;
        return $c->render_resource_deleted;
    } catch {
        $c->unhandled_exception($_);
    };
}

1;
