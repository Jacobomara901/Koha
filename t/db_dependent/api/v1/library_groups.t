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
use Test::More tests => 2;
use Test::Mojo;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::Database;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

my $t = Test::Mojo->new('Koha::REST::V1');

subtest 'list() tests' => sub {

    plan tests => 13;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**2 }
        }
    );
    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }
        }
    );

    my $password = 'thePassword123';

    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $unauth_userid = $patron->userid;

    $t->get_ok("//$unauth_userid:$password@/api/v1/library_groups")
        ->status_is(403)
        ->json_is( '/error' => 'Authorization failure. Missing required permission(s).' );

    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $group = $builder->build_object(
        {
            class => 'Koha::Library::Groups',
            value => { parent_id => undef, branchcode => undef, ft_record_source_editing => 1 }
        }
    );
    $builder->build_object(
        {
            class => 'Koha::Library::Groups',
            value => { parent_id => undef, branchcode => undef, ft_record_source_editing => 0 }
        }
    );

    my $id = $group->id;
    $t->get_ok("//$userid:$password@/api/v1/library_groups?q={\"library_group_id\": $id}")
        ->status_is( 200, 'REST3.2.2' )
        ->json_is( '/0/library_group_id'         => $group->id )
        ->json_is( '/0/title'                    => $group->title )
        ->json_is( '/0/ft_record_source_editing' => Mojo::JSON->true );

    $t->get_ok(
        "//$userid:$password@/api/v1/library_groups?q={\"ft_record_source_editing\": true, \"library_group_id\": { \"-in\": [$id] }}"
    )->status_is(200)->json_is( '/0/library_group_id' => $group->id );

    my $rs_manager = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 0 } } );
    $builder->build(
        {
            source => 'UserPermission',
            value  => {
                borrowernumber => $rs_manager->id,
                module_bit     => 3,
                code           => 'manage_record_sources',
            },
        }
    );
    $rs_manager->set_password( { password => $password, skip_validation => 1 } );
    my $rs_manager_userid = $rs_manager->userid;

    $t->get_ok("//$rs_manager_userid:$password@/api/v1/library_groups")
        ->status_is( 200, 'manage_record_sources also grants access' );

    $schema->storage->txn_rollback;
};
