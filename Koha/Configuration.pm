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

1;
