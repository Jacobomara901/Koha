package Koha::REST::V1::DeletedPatrons;

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
# along with Koha; if not, see <https://www.gnu.org/licenses>.

use Modern::Perl;

use Mojo::Base 'Mojolicious::Controller';

use Scalar::Util qw( blessed );
use Try::Tiny    qw( catch try );

use C4::Context;

use Koha::Old::Patrons;

=head1 API

=head2 Methods

=head3 list

Controller function that handles listing deleted patron objects

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return _render_restoration_disabled($c)
        unless C4::Context->preference('AllowDeletedPatronRestoration');

    return try {
        my $deleted_patrons_rs = Koha::Old::Patrons->search_limited;
        my $deleted_patrons    = $c->objects->search($deleted_patrons_rs);

        return $c->render(
            status  => 200,
            openapi => $deleted_patrons
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 restore

Controller function that handles restoring a single deleted patron object

=cut

sub restore {
    my $c = shift->openapi->valid_input or return;

    return _render_restoration_disabled($c)
        unless C4::Context->preference('AllowDeletedPatronRestoration');

    my $deleted_patron =
        Koha::Old::Patrons->search_limited( { borrowernumber => $c->param('patron_id') } )->next;

    return $c->render_resource_not_found("Deleted patron")
        unless $deleted_patron;

    return try {
        my $patron = $deleted_patron->restore;

        return $c->render(
            status  => 200,
            openapi => $c->objects->to_api($patron),
        );
    } catch {
        if ( blessed $_ && $_->isa('Koha::Exceptions::Patron::CannotRestore') ) {
            return $c->render(
                status  => 409,
                openapi => { error => "Cannot restore patron: " . $_->error }
            );
        }
        $c->unhandled_exception($_);
    };
}

=head2 Internal methods

=head3 _render_restoration_disabled

Renders the 403 response used when the AllowDeletedPatronRestoration system
preference is off.

=cut

sub _render_restoration_disabled {
    my ($c) = @_;

    return $c->render(
        status  => 403,
        openapi => { error => "The AllowDeletedPatronRestoration system preference is disabled" }
    );
}

1;
