#!/usr/bin/env perl

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

use Test::NoWarnings;
use Test::More tests => 4;
use Test::Mojo;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::Database;
use Koha::Library::Group;
use Koha::Old::Patrons;
use Koha::Patrons;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');
t::lib::Mocks::mock_preference( 'RESTBasicAuth',                 1 );
t::lib::Mocks::mock_preference( 'AllowDeletedPatronRestoration', 1 );

my $password = 'thePassword123';

sub delete_patron {
    my ($patron) = @_;
    my $deleted_patron = Koha::Old::Patron->new( $patron->unblessed )->store;
    $patron->delete;
    return $deleted_patron;
}

subtest 'list() tests' => sub {

    plan tests => 11;

    $schema->storage->txn_begin;

    Koha::Old::Patrons->search->delete;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**13 }
        }
    );
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }
        }
    );
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $unauth_userid = $patron->userid;

    $t->get_ok("//$userid:$password@/api/v1/deleted/patrons")->status_is(200)->json_is( [] );

    my $deleted_patron = delete_patron(
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $librarian->branchcode } } ) );

    $t->get_ok("//$userid:$password@/api/v1/deleted/patrons")->status_is(200);

    $t->json_has('/0')->json_is( '/0' => $deleted_patron->to_api );

    $t->get_ok("//$unauth_userid:$password@/api/v1/deleted/patrons")->status_is(403);

    t::lib::Mocks::mock_preference( 'AllowDeletedPatronRestoration', 0 );
    $t->get_ok("//$userid:$password@/api/v1/deleted/patrons")->status_is(200);
    t::lib::Mocks::mock_preference( 'AllowDeletedPatronRestoration', 1 );

    $schema->storage->txn_rollback;
};

subtest 'list() library group visibility tests' => sub {

    plan tests => 7;

    $schema->storage->txn_begin;

    Koha::Old::Patrons->search->delete;

    my $library1 = $builder->build_object( { class => 'Koha::Libraries' } );
    my $library2 = $builder->build_object( { class => 'Koha::Libraries' } );

    my $group = Koha::Library::Group->new( { title => 'Hidden group', ft_hide_patron_info => 1 } )->store;
    Koha::Library::Group->new( { parent_id => $group->id, branchcode => $library1->branchcode } )->store;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**13, branchcode => $library1->branchcode }
        }
    );
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $deleted_patron1 = delete_patron(
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library1->branchcode } } ) );
    my $deleted_patron2 = delete_patron(
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library2->branchcode } } ) );

    $t->get_ok("//$userid:$password@/api/v1/deleted/patrons")->status_is(200);

    my $json = $t->tx->res->json;
    is( scalar @$json,         1,                                'Librarian only sees patrons from their group' );
    is( $json->[0]{patron_id}, $deleted_patron1->borrowernumber, 'The visible patron is from the same group' );

    my $superlibrarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 1, branchcode => $library1->branchcode }
        }
    );
    $superlibrarian->set_password( { password => $password, skip_validation => 1 } );
    my $super_userid = $superlibrarian->userid;

    $t->get_ok("//$super_userid:$password@/api/v1/deleted/patrons")->status_is(200);

    $json = $t->tx->res->json;
    is( scalar @$json, 2, 'Superlibrarian sees deleted patrons from all libraries' );

    $schema->storage->txn_rollback;
};

subtest 'restore() tests' => sub {

    plan tests => 17;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }
        }
    );
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    $builder->build(
        {
            source => 'UserPermission',
            value  => {
                borrowernumber => $librarian->borrowernumber,
                module_bit     => 13,
                code           => 'restore_deleted_borrowers',
            }
        }
    );

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }
        }
    );
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $unauth_userid = $patron->userid;

    my $patron_to_delete =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $librarian->branchcode } } );
    my $patron_id      = $patron_to_delete->borrowernumber;
    my $cardnumber     = $patron_to_delete->cardnumber;
    my $deleted_patron = delete_patron($patron_to_delete);

    is( Koha::Patrons->find($patron_id), undef, 'Patron deleted successfully' );
    ok( $deleted_patron, 'Patron found in deleted table' );

    $t->put_ok("//$unauth_userid:$password@/api/v1/deleted/patrons/$patron_id")->status_is(403);

    $t->put_ok("//$userid:$password@/api/v1/deleted/patrons/$patron_id")->status_is(200);

    my $restored_patron = Koha::Patrons->find($patron_id);
    ok( $restored_patron, 'Patron restored successfully' );
    is( $restored_patron->cardnumber, $cardnumber, 'Patron cardnumber preserved' );

    is( Koha::Old::Patrons->search( { borrowernumber => $patron_id } )->count, 0, 'Patron removed from deleted table' );

    $t->put_ok("//$userid:$password@/api/v1/deleted/patrons/$patron_id")->status_is(404);

    my $live_patron = $builder->build_object( { class => 'Koha::Patrons' } );
    my $conflict_patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $librarian->branchcode } } );
    my $conflict_id   = $conflict_patron->borrowernumber;
    my $conflict_data = $conflict_patron->unblessed;
    $conflict_data->{cardnumber} = $live_patron->cardnumber;
    $conflict_patron->delete;
    Koha::Old::Patron->new($conflict_data)->store;

    $t->put_ok("//$userid:$password@/api/v1/deleted/patrons/$conflict_id")
        ->status_is(409)
        ->json_has('/error')
        ->json_like( '/error', qr/Cardnumber already in use/ );

    t::lib::Mocks::mock_preference( 'AllowDeletedPatronRestoration', 0 );
    $t->put_ok("//$userid:$password@/api/v1/deleted/patrons/$conflict_id")->status_is(403);
    t::lib::Mocks::mock_preference( 'AllowDeletedPatronRestoration', 1 );

    $schema->storage->txn_rollback;
};
