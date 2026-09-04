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

use Test::More tests => 4;
use Test::Exception;
use Test::NoWarnings;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::ActionLogs;
use Koha::Database;
use Koha::Old::Patrons;
use Koha::Patrons;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

sub delete_patron {
    my ($patron) = @_;
    my $borrowernumber = $patron->borrowernumber;
    Koha::Patrons->search( { borrowernumber => $borrowernumber } )->delete( { move => 1 } );
    return Koha::Old::Patrons->search( { borrowernumber => $borrowernumber } )->next;
}

subtest 'restore' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    my $patron         = $builder->build_object( { class => 'Koha::Patrons' } );
    my $borrowernumber = $patron->borrowernumber;
    my $cardnumber     = $patron->cardnumber;

    my $deleted_patron = delete_patron($patron);
    ok( $deleted_patron, 'Patron moved to deletedborrowers' );

    my $restored = $deleted_patron->restore;

    ok( $restored, 'Restored patron exists' );
    is( $restored->borrowernumber, $borrowernumber, 'Borrowernumber matches' );
    is( $restored->cardnumber,     $cardnumber,     'Cardnumber matches' );

    $schema->storage->txn_rollback;
};

subtest 'restore conflicts' => sub {
    plan tests => 6;

    $schema->storage->txn_begin;

    my $live  = $builder->build_object( { class => 'Koha::Patrons' } );
    my $clash = Koha::Old::Patron->new( $live->unblessed )->store;

    throws_ok { $clash->restore } 'Koha::Exceptions::Patron::CannotRestore',
        'An existing borrowernumber blocks the restore';
    is( $@->type, 'borrowernumber', 'Conflict type is borrowernumber' );

    my $deleted = delete_patron( $builder->build_object( { class => 'Koha::Patrons' } ) );
    $live->cardnumber( $deleted->cardnumber )->store;

    throws_ok { $deleted->restore } 'Koha::Exceptions::Patron::CannotRestore',
        'An existing cardnumber blocks the restore';
    is( $@->type, 'cardnumber', 'Conflict type is cardnumber' );

    my $deleted_userid = delete_patron( $builder->build_object( { class => 'Koha::Patrons' } ) );
    $live->userid( $deleted_userid->userid )->store;

    throws_ok { $deleted_userid->restore } 'Koha::Exceptions::Patron::CannotRestore',
        'An existing userid blocks the restore';
    is( $@->type, 'userid', 'Conflict type is userid' );

    $schema->storage->txn_rollback;
};

subtest 'restore clears restrictions and flags, and logs' => sub {
    plan tests => 5;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'BorrowersLog', 1 );

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 1, debarred => '2099-12-31', debarredcomment => 'Blocked' }
        }
    );
    my $borrowernumber = $patron->borrowernumber;

    my $restored = delete_patron($patron)->restore;

    is( $restored->flags,           undef, 'Permission flags are cleared' );
    is( $restored->debarred,        undef, 'Restriction date is cleared' );
    is( $restored->debarredcomment, undef, 'Restriction comment is cleared' );

    my $logs = Koha::ActionLogs->search( { module => 'MEMBERS', action => 'Restore', object => $borrowernumber } );
    is( $logs->count, 1, 'The restore is logged once' );
    like( $logs->next->info, qr/^Deleted patron restored: /, 'The log entry names the restored patron' );

    $schema->storage->txn_rollback;
};
