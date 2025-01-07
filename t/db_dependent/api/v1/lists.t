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

use Test::More tests => 6;
use Test::Mojo;
use Test::NoWarnings;

use JSON qw(encode_json);

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::Virtualshelves;
use Koha::Database;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');
t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

subtest 'list() tests' => sub {
    plan tests => 13;

    $schema->storage->txn_begin;

    my $password = 'thePassword123';

    # Create librarian with necessary permissions (catalogue + lists)
    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 4 + 2**20 }    # catalogue + lists permissions
        }
    );
    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }            # no permissions
        }
    );

    $librarian->set_password( { password => $password, skip_validation => 1 } );
    $patron->set_password( { password => $password, skip_validation => 1 } );

    my $librarian_userid = $librarian->userid;
    my $unauth_userid    = $patron->userid;

    ## Authorized user tests
    # No lists, so empty array should be returned
    $t->get_ok("//$librarian_userid:$password@/api/v1/lists")->status_is(200)->json_is( [] );

    # Create test lists owned by librarian
    my $list_1 = $builder->build_object(
        {
            class => 'Koha::Virtualshelves',
            value => { owner => $librarian->id, public => 1 }
        }
    );
    my $list_2 = $builder->build_object(
        {
            class => 'Koha::Virtualshelves',
            value => { owner => $librarian->id, public => 0 }
        }
    );

    # One list
    my $q = encode_json( { list_id => $list_1->id } );
    $t->get_ok("//$librarian_userid:$password@/api/v1/lists?q=$q")->status_is(200)->json_is( [ $list_1->to_api ] );

    # Multiple lists
    $q = encode_json( { list_id => { -in => [ $list_1->id, $list_2->id ] } } );
    $t->get_ok("//$librarian_userid:$password@/api/v1/lists?q=$q")->status_is(200)
        ->json_is( [ $list_1->to_api, $list_2->to_api ] );

    # Unauthorized access
    $t->get_ok("/api/v1/lists?q=$q")->status_is( 401, "Anonymous users cannot access admin lists endpoint" );

    $t->get_ok("//$unauth_userid:$password@/api/v1/lists?q=$q")
        ->status_is( 403, "Patrons without permission cannot access admin lists endpoint" );

    $schema->storage->txn_rollback;
};

subtest 'get() tests' => sub {
    plan tests => 14;

    $schema->storage->txn_begin;

    my $password = 'thePassword123';

    # Create librarian with necessary permissions (catalogue + lists)
    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 4 + 2**20 }    # catalogue + lists permissions
        }
    );
    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }            # no permissions
        }
    );

    $librarian->set_password( { password => $password, skip_validation => 1 } );
    $patron->set_password( { password => $password, skip_validation => 1 } );

    my $librarian_userid = $librarian->userid;
    my $unauth_userid    = $patron->userid;

    # Create test lists
    my $public_list = $builder->build_object(
        {
            class => 'Koha::Virtualshelves',
            value => { owner => $patron->id, public => 1 }
        }
    );

    my $private_list = $builder->build_object(
        {
            class => 'Koha::Virtualshelves',
            value => { owner => $patron->id, public => 0 }
        }
    );

    ## Authorized user tests
    # Librarian can view public list
    $t->get_ok( "//$librarian_userid:$password@/api/v1/lists/" . $public_list->id )->status_is(200)
        ->json_is( $public_list->to_api );

    # Librarian can view own list
    my $librarian_list = $builder->build_object(
        {
            class => 'Koha::Virtualshelves',
            value => { owner => $librarian->id, public => 0 }
        }
    );

    $t->get_ok( "//$librarian_userid:$password@/api/v1/lists/" . $librarian_list->id )->status_is(200)
        ->json_is( $librarian_list->to_api );

    # Librarian cannot view another patron's private list
    $t->get_ok( "//$librarian_userid:$password@/api/v1/lists/" . $private_list->id )->status_is(403);

    ## Unauthorized user tests
    $t->get_ok( "/api/v1/lists/" . $public_list->id )->status_is(401);

    $t->get_ok( "//$unauth_userid:$password@/api/v1/lists/" . $public_list->id )->status_is(403);

    # Not found
    my $list_to_delete  = $builder->build_object( { class => 'Koha::Virtualshelves' } );
    my $non_existent_id = $list_to_delete->id;
    $list_to_delete->delete;

    $t->get_ok("//$librarian_userid:$password@/api/v1/lists/$non_existent_id")->status_is(404);

    $schema->storage->txn_rollback;
};

subtest 'add() tests' => sub {
    plan tests => 20;

    $schema->storage->txn_begin;

    my $password = 'thePassword123';

    # Create librarian with necessary permissions (catalogue + lists)
    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 4 + 2**20 }    # catalogue + lists permissions
        }
    );
    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }            # no permissions
        }
    );
    my $another_patron = $builder->build_object( { class => 'Koha::Patrons' } );

    $librarian->set_password( { password => $password, skip_validation => 1 } );
    $patron->set_password( { password => $password, skip_validation => 1 } );

    my $librarian_userid = $librarian->userid;
    my $unauth_userid    = $patron->userid;

    my $list_data = {
        name                     => "Test List",
        owner_id                 => $librarian->id,
        public                   => 1,
        allow_change_from_owner  => 1,
        allow_change_from_others => 0,
        default_sort_field       => 'title'
    };

    ## Unauthorized attempts
    $t->post_ok( "/api/v1/lists" => json => $list_data )->status_is(401);

    $t->post_ok( "//$unauth_userid:$password@/api/v1/lists" => json => $list_data )->status_is(403);

    ## Authorized user tests
    # Create list for self
    my $list_id =
        $t->post_ok( "//$librarian_userid:$password@/api/v1/lists" => json => $list_data )
        ->status_is( 201, 'REST3.2.1' )->header_like( Location => qr|^/api/v1/lists/\d+|, 'REST3.4.1' )
        ->json_is( '/name'   => $list_data->{name} )->json_is( '/owner_id' => $list_data->{owner_id} )
        ->json_is( '/public' => $list_data->{public} )->tx->res->json->{list_id};

    # Create list for another patron
    my $list_for_patron = {
        name                     => "Test List for Patron",
        owner_id                 => $another_patron->id,
        public                   => 0,
        allow_change_from_owner  => 1,
        allow_change_from_others => 0,
        default_sort_field       => 'title'
    };

    $t->post_ok( "//$librarian_userid:$password@/api/v1/lists" => json => $list_for_patron )->status_is(201)
        ->json_is( '/owner_id' => $another_patron->id )->json_is( '/name' => 'Test List for Patron' );

    # Invalid owner_id
    my $list_invalid_owner = {
        name                     => "Test List",
        owner_id                 => 999999,
        public                   => 1,
        allow_change_from_owner  => 1,
        allow_change_from_others => 0,
        default_sort_field       => 'title'
    };

    $t->post_ok( "//$librarian_userid:$password@/api/v1/lists" => json => $list_invalid_owner )->status_is(400)
        ->json_like( '/error' => qr/Invalid owner_id/ );

    # Test that sortfield is validated (UNIMARC conversion happens in store)
    my $list_with_sortfield = {
        name                     => "Test List with Sort",
        owner_id                 => $librarian->id,
        public                   => 1,
        allow_change_from_owner  => 1,
        allow_change_from_others => 0,
        default_sort_field       => 'copyrightdate'
    };

    $t->post_ok( "//$librarian_userid:$password@/api/v1/lists" => json => $list_with_sortfield )->status_is(201)
        ->json_has('/default_sort_field');

    $schema->storage->txn_rollback;
};

subtest 'update() tests' => sub {
    plan tests => 24;

    $schema->storage->txn_begin;

    my $password = 'thePassword123';

    # Create librarian with necessary permissions (catalogue + lists)
    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 4 + 2**20 }    # catalogue + lists permissions
        }
    );
    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }            # no permissions
        }
    );

    $librarian->set_password( { password => $password, skip_validation => 1 } );
    $patron->set_password( { password => $password, skip_validation => 1 } );

    my $librarian_userid = $librarian->userid;
    my $unauth_userid    = $patron->userid;

    # Create test list owned by librarian
    my $list = $builder->build_object(
        {
            class => 'Koha::Virtualshelves',
            value => {
                owner                    => $librarian->id,
                public                   => 1,
                allow_change_from_owner  => 1,
                allow_change_from_others => 0
            }
        }
    );

    my $update_data = {
        name                     => "Updated List Name",
        public                   => 0,
        allow_change_from_owner  => 1,
        allow_change_from_others => 0,
        default_sort_field       => 'title'
    };

    ## Unauthorized attempts
    $t->put_ok( "/api/v1/lists/" . $list->id => json => $update_data )->status_is(401);

    $t->put_ok( "//$unauth_userid:$password@/api/v1/lists/" . $list->id => json => $update_data )->status_is(403);

    ## Authorized user tests
    # Owner can update own list
    $t->put_ok( "//$librarian_userid:$password@/api/v1/lists/" . $list->id => json => $update_data )->status_is(200)
        ->json_is( '/name' => 'Updated List Name' )->json_is( '/public' => 0 );

    # Not found
    $t->put_ok( "//$librarian_userid:$password@/api/v1/lists/99999999" => json => $update_data )->status_is(404);

    # Librarian with edit_public_lists can update PUBLIC list owned by another patron
    my $patron_public_list = $builder->build_object(
        {
            class => 'Koha::Virtualshelves',
            value => {
                owner  => $patron->id,
                public => 1
            }
        }
    );

    my $update_data_2 = {
        name                     => "Updated by Librarian",
        public                   => 1,
        allow_change_from_owner  => 1,
        allow_change_from_others => 0,
        default_sort_field       => 'title'
    };

    $t->put_ok( "//$librarian_userid:$password@/api/v1/lists/" . $patron_public_list->id => json => $update_data_2 )
        ->status_is(200)->json_is( '/name' => 'Updated by Librarian' );

    # Librarian with edit_public_lists CANNOT update PRIVATE list owned by another patron
    my $patron_private_list = $builder->build_object(
        {
            class => 'Koha::Virtualshelves',
            value => {
                owner  => $patron->id,
                public => 0
            }
        }
    );

    $t->put_ok( "//$librarian_userid:$password@/api/v1/lists/" . $patron_private_list->id => json => $update_data_2 )
        ->status_is(403);

    # Owner can always update their own list (allow_change_from_owner doesn't block property updates)
    my $owner_list = $builder->build_object(
        {
            class => 'Koha::Virtualshelves',
            value => {
                owner                   => $librarian->id,
                public                  => 1,
                allow_change_from_owner => 0                 # This flag only affects list CONTENT, not properties
            }
        }
    );

    my $update_data_3 = {
        name                     => "Owner Can Update",
        public                   => 1,
        allow_change_from_owner  => 0,
        allow_change_from_others => 0,
        default_sort_field       => 'author'
    };

    $t->put_ok( "//$librarian_userid:$password@/api/v1/lists/" . $owner_list->id => json => $update_data_3 )
        ->status_is(200)->json_is( '/name' => 'Owner Can Update' );

    # Test sortfield validation and UNIMARC handling
    my $update_with_sortfield = {
        name                     => "List with Sortfield",
        public                   => 1,
        allow_change_from_owner  => 1,
        allow_change_from_others => 0,
        default_sort_field       => 'copyrightdate'          # Will be converted to publicationyear for UNIMARC
    };

    $t->put_ok( "//$librarian_userid:$password@/api/v1/lists/" . $list->id => json => $update_with_sortfield )
        ->status_is(200)->json_has('/default_sort_field');

    # Test invalid sortfield gets defaulted to 'title'
    my $update_invalid_sort = {
        name                     => "List with Invalid Sort",
        public                   => 1,
        allow_change_from_owner  => 1,
        allow_change_from_others => 0,
        default_sort_field       => 'invalid_field'
    };

    $t->put_ok( "//$librarian_userid:$password@/api/v1/lists/" . $list->id => json => $update_invalid_sort )
        ->status_is(200)->json_is( '/default_sort_field' => 'title' );

    $schema->storage->txn_rollback;
};

subtest 'delete() tests' => sub {
    plan tests => 17;

    $schema->storage->txn_begin;

    my $password = 'thePassword123';

    # Create librarian with necessary permissions (catalogue + lists)
    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 4 + 2**20 }    # catalogue + lists permissions
        }
    );
    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }            # no permissions
        }
    );

    $librarian->set_password( { password => $password, skip_validation => 1 } );
    $patron->set_password( { password => $password, skip_validation => 1 } );

    my $librarian_userid = $librarian->userid;
    my $unauth_userid    = $patron->userid;

    # Create test list owned by librarian
    my $list = $builder->build_object(
        {
            class => 'Koha::Virtualshelves',
            value => { owner => $librarian->id, public => 1 }
        }
    );

    ## Unauthorized attempts
    $t->delete_ok( "/api/v1/lists/" . $list->id )->status_is(401);

    $t->delete_ok( "//$unauth_userid:$password@/api/v1/lists/" . $list->id )->status_is(403);

    ## Authorized user tests
    # Owner can delete own list
    $t->delete_ok( "//$librarian_userid:$password@/api/v1/lists/" . $list->id )->status_is( 204, 'REST3.2.4' )
        ->content_is( '', 'REST3.3.4' );

    # Already deleted (not found)
    $t->delete_ok( "//$librarian_userid:$password@/api/v1/lists/" . $list->id )->status_is(404);

    # Librarian with delete_public_lists can delete PUBLIC list owned by another patron
    my $patron_public_list = $builder->build_object(
        {
            class => 'Koha::Virtualshelves',
            value => {
                owner  => $patron->id,
                public => 1
            }
        }
    );

    $t->delete_ok( "//$librarian_userid:$password@/api/v1/lists/" . $patron_public_list->id )->status_is(204);

    # Librarian with delete_public_lists CANNOT delete PRIVATE list owned by another patron
    my $patron_private_list = $builder->build_object(
        {
            class => 'Koha::Virtualshelves',
            value => {
                owner  => $patron->id,
                public => 0
            }
        }
    );

    $t->delete_ok( "//$librarian_userid:$password@/api/v1/lists/" . $patron_private_list->id )->status_is(403);

    # Owner can always delete their own list (allow_change_from_owner doesn't block deletion)
    my $owner_list = $builder->build_object(
        {
            class => 'Koha::Virtualshelves',
            value => {
                owner                   => $librarian->id,
                public                  => 1,
                allow_change_from_owner => 0                 # This flag only affects list CONTENT, not deletion
            }
        }
    );

    $t->delete_ok( "//$librarian_userid:$password@/api/v1/lists/" . $owner_list->id )->status_is(204);

    # Test patron can delete their own list even without special permissions
    my $patron_own_list = $builder->build_object(
        {
            class => 'Koha::Virtualshelves',
            value => {
                owner  => $patron->id,
                public => 0
            }
        }
    );

    # Give patron minimal permissions to access their own list
    my $patron_with_list = Koha::Patrons->find( $patron->id );
    $patron_with_list->flags(4);    # catalogue permission
    $patron_with_list->store;

    $t->delete_ok( "//$unauth_userid:$password@/api/v1/lists/" . $patron_own_list->id )->status_is(403)
        ;                           # Still 403 because patron needs lists permission

    $schema->storage->txn_rollback;
};

1;
