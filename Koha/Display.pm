package Koha::Display;

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
use Koha::DisplayItems;
use Koha::Library;
use Koha::ItemType;

use base qw(Koha::Object);

=head1 NAME

Koha::Display - Koha Display Object class

=head1 API

=head2 Class methods

=cut

=head3 display_items

    my $display_items = $display->display_items;

Returns the related Koha::DisplayItems object for this display.

=cut

sub display_items {
    my ( $self, $display_items ) = @_;

    if ($display_items) {
        my $schema = $self->_result->result_source->schema;
        $schema->txn_do(
            sub {
                $self->display_items->delete;

                for my $display_item (@$display_items) {
                    $self->_result->add_to_display_items($display_item);
                }
            }
        );
    }

    my $display_items_rs = $self->_result->display_items;
    return Koha::DisplayItems->_new_from_dbic($display_items_rs);
}

=head3 library

    my $library = $display->library;

Returns the related Koha::Library object for this display's branch.

=cut

sub library {
    my ($self) = @_;
    my $rs = $self->_result->display_branch;
    return unless $rs;
    return Koha::Library->_new_from_dbic($rs);
}

=head3 item_type

    my $item_type = $display->item_type;

Returns the related Koha::ItemType object for this display's item type.

=cut

sub item_type {
    my ($self) = @_;
    my $rs = $self->_result->display_type;
    return unless $rs;
    return Koha::ItemType->_new_from_dbic($rs);
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'Display';
}

=head1 AUTHOR

Koha Development Team <http://koha-community.org/>

=cut

1;
