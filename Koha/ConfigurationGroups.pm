package Koha::ConfigurationGroups;

# Copyright BibLibre 2024
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
use Koha::ConfigurationGroup;

use base qw(Koha::Objects);

=head1 NAME

Koha::ConfigurationGroups - Koha ConfigurationGroups Object set class

=head1 API

=head2 Class Methods

=cut

=head3 find_by_flag

    my $group = Koha::ConfigurationGroups->find_by_flag($flag);

Get a configuration group by its flag name (rather than bit number).
This is more user-friendly than referring to groups by their bit.

Parameters:
  - $flag: The flag name of the configuration group to find

Returns:
  - A Koha::ConfigurationGroup object or undef if not found

=cut

sub find_by_flag {
    my ($self, $flag) = @_;

    return $self->find({ flag => $flag });
}

=head3 _type

=cut

sub _type {
    return 'ConfigurationGroup';
}

=head3 object_class

=cut

sub object_class {
    return 'Koha::ConfigurationGroup';
}

1;
