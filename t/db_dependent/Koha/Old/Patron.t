#!/usr/bin/perl

# Copyright 2025 Koha
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
# along with Koha; if not, see <https://www.gnu.org/licenses>.

use Modern::Perl;

use Test::More tests => 2;
use Test::Exception;
use Test::MockModule;

use t::lib::TestBuilder;
use t::lib::Mocks;
use Test::NoWarnings;

use Koha::Database;
use Koha::Patrons;
use Koha::Old::Patrons;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'restore' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    #create a test patron
    my $patron         = $builder->build_object( { class => 'Koha::Patrons' } );
    my $borrowernumber = $patron->borrowernumber;
    my $cardnumber     = $patron->cardnumber;

    #delete the created patron, using move = 1 to ensure they go to deleteborrowers
    my $to_delete = Koha::Patrons->search( { borrowernumber => $borrowernumber } );
    $to_delete->delete( { move => 1 } );

    #verify patron is in deletedborrowers
    my $deleted_patron = Koha::Old::Patrons->search( { borrowernumber => $borrowernumber } )->next;
    ok( $deleted_patron, 'Patron moved to deletedborrowers' );

    #restore the deleted patron
    my $restored = $deleted_patron->restore;

    #verify the patron is restored
    ok( $restored, 'Restored patron exists' );
    is( $restored->borrowernumber, $borrowernumber, 'Borrowernumber matches' );
    is( $restored->cardnumber,     $cardnumber,     'Cardnumber matches' );

    $schema->storage->txn_rollback;
};
