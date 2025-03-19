package Koha::ConfigurationGroup;

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
use Koha::Configurations;

use base qw(Koha::Object);

=head1 NAME

Koha::ConfigurationGroup - Koha ConfigurationGroup Object class

=head1 API

=head2 Class Methods

=cut

=head3 configurations

    my $configurations = $group->configurations;

Returns the configurations belonging to this configuration group.

=cut

sub configurations {
    my ($self) = @_;

    return Koha::Configurations->search({ configuration_group_bit => $self->bit });
}

=head3 type

=cut

sub _type {
    return 'ConfigurationGroup';
}

1;
