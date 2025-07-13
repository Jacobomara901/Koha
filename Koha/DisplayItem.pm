package Koha::DisplayItem;

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

use Carp;

use Koha::Database;
use Koha::Display;
use Koha::Item;
use Koha::Biblio;

use base qw(Koha::Object);

=head1 NAME

Koha::DisplayItem - Koha Display Item Object class

=head1 API

=head2 Class methods

=cut

=head3 display

    my $display = $display_item->display;

Returns the related Koha::Display object for this display item.

=cut

sub display {
    my ($self) = @_;
    my $rs = $self->_result->display;
    return Koha::Display->_new_from_dbic($rs);
}

=head3 item

    my $item = $display_item->item;

Returns the related Koha::Item object for this display item.

=cut

sub item {
    my ($self) = @_;
    my $rs = $self->_result->itemnumber;
    return unless $rs;
    return Koha::Item->_new_from_dbic($rs);
}

=head3 biblio

    my $biblio = $display_item->biblio;

Returns the related Koha::Biblio object for this display item.

=cut

sub biblio {
    my ($self) = @_;
    my $rs = $self->_result->biblionumber;
    return unless $rs;
    return Koha::Biblio->_new_from_dbic($rs);
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'DisplayItem';
}

=head1 AUTHOR

Koha Development Team <http://koha-community.org/>

=cut

1;
