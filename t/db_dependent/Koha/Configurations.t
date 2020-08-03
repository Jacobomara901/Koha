#!/usr/bin/perl

# Copyright 2020 Koha Development team
#
# This file is part of Koha
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

use Test::More tests => 1;
use Test::Exception;

use Koha::Configurations;
use Koha::Database;

use t::lib::TestBuilder;
use t::lib::Mocks;

my $schema = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'set_config + get_effective_config' => sub {

    plan tests => 17;

    $schema->storage->txn_begin;

    my $category_id  = $builder->build_object( { class => 'Koha::Patron::Categories' } )->categorycode;
    my $item_type    = $builder->build_object( { class => 'Koha::ItemTypes' } )->itemtype;
    my $library_id   = $builder->build_object( { class => 'Koha::Libraries' } )->branchcode;
    my $library_id_2 = $builder->build_object( { class => 'Koha::Libraries' } )->branchcode;

    my $name          = 'smtp_server';
    my $default_value = 'localhost';

    my $server_1 = 'smtp.demo1.edu';
    my $server_2 = 'smtp.demo2.edu';
    my $server_3 = 'smtp.demo3.edu';
    my $server_4 = 'smtp.demo4.edu';
    my $server_5 = 'smtp.demo5.edu';
    my $server_6 = 'smtp.demo6.edu';
    my $server_7 = 'smtp.demo7.edu';

    my $config;

    Koha::Configurations->delete;

    throws_ok { Koha::Configurations->get_effective_config }
    'Koha::Exceptions::MissingParameter',
    "Exception should be raised if get_effective_config is called without name parameter";

    $config = Koha::Configurations->get_effective_config(
        {
            library_id  => $library_id,
            category_id => $category_id,
            item_type   => $item_type,
            name        => $name,
        }
    );
    is( $config, undef, 'Undef should be returned if no rule exist' );

    # Set a default value
    Koha::Configurations->set_config(
        {
            library_id  => undef,
            category_id => undef,
            item_type   => undef,
            name        => $name,
            value       => $default_value,
        }
    );

    $config = Koha::Configurations->get_effective_config(
        {
            library_id  => undef,
            category_id => undef,
            item_type   => undef,
            name        => $name,
        }
    );
    is( $config->value, $default_value, 'undef means default' );

    Koha::Configurations->set_config(
        {
            library_id  => undef,
            category_id => undef,
            item_type   => $item_type,
            name        => $name,
            value       => $server_1,
        }
    );

    $config = Koha::Configurations->get_effective_config(
        {
            library_id  => $library_id,
            category_id => $category_id,
            item_type   => $item_type,
            name        => $name,
        }
    );
    is( $config->value, $server_1,
        'More specific rule is returned when item_type is given' );

    $config = Koha::Configurations->get_effective_config(
        {
            library_id  => $library_id_2,
            category_id => undef,
            item_type   => undef,
            name        => $name,
        }
    );
    is( $config->value, $default_value,
        'Default rule is returned if there is no rule for this library_id' );

    Koha::Configurations->set_config(
        {
            library_id  => undef,
            category_id => $category_id,
            item_type   => undef,
            name        => $name,
            value       => $server_2,
        }
    );

    $config = Koha::Configurations->get_effective_config(
        {

            library_id  => $library_id,
            category_id => $category_id,
            item_type   => $item_type,
            name        => $name,
        }
    );
    is( $config->value, $server_2,
        'More specific rule is returned when category_id exists' );

    Koha::Configurations->set_config(
        {
            library_id  => undef,
            category_id => $category_id,
            item_type   => $item_type,
            name        => $name,
            value       => $server_3,
        }
    );
    $config = Koha::Configurations->get_effective_config(
        {
            library_id  => $library_id,
            category_id => $category_id,
            item_type   => $item_type,
            name        => $name,
        }
    );
    is( $config->value, $server_3,
        'More specific rule is returned when category_id and item_type exist' );

    Koha::Configurations->set_config(
        {
            library_id  => $library_id,
            category_id => undef,
            item_type   => undef,
            name        => $name,
            value       => $server_4,
        }
    );
    $config = Koha::Configurations->get_effective_config(
        {
            library_id  => $library_id,
            category_id => $category_id,
            item_type   => $item_type,
            name        => $name,
        }
    );
    is( $config->value, $server_4,
        'More specific rule is returned when library_id exists' );

    Koha::Configurations->set_config(
        {
            library_id  => $library_id,
            category_id => undef,
            item_type   => $item_type,
            name        => $name,
            value       => $server_5,
        }
    );
    $config = Koha::Configurations->get_effective_config(
        {
            library_id  => $library_id,
            category_id => $category_id,
            item_type   => $item_type,
            name        => $name,
        }
    );
    is( $config->value, $server_5,
        'More specific rule is returned when library_id and item_type exists' );

    Koha::Configurations->set_config(
        {
            library_id  => $library_id,
            category_id => $category_id,
            item_type   => undef,
            name        => $name,
            value       => $server_6,
        }
    );
    $config = Koha::Configurations->get_effective_config(
        {
            library_id  => $library_id,
            category_id => $category_id,
            item_type   => $item_type,
            name        => $name,
        }
    );
    is( $config->value, $server_6,
        'More specific rule is returned when library_id and category_id exist'
    );

    Koha::Configurations->set_config(
        {
            library_id  => $library_id,
            category_id => $category_id,
            item_type   => $item_type,
            name        => $name,
            value       => $server_7,
        }
    );
    $config = Koha::Configurations->get_effective_config(
        {
            library_id  => $library_id,
            category_id => $category_id,
            item_type   => $item_type,
            name        => $name,
        }
    );
    is( $config->value, $server_7,
        'More specific rule is returned when library_id, category_id and item_type exist'
    );

    my $library_configs = Koha::Configurations->search({ library_id => $library_id });
    is( $library_configs->count, 4, "We added 8 rules");
    $library_configs->delete;
    is( $library_configs->count, 0, "We deleted 8 rules");

    throws_ok {
        Koha::Configurations->set_config(
            {
                library_id  => $library_id,
                category_id => $category_id,
                item_type   => $item_type,
                value       => $server_7,
            }
        );
    } 'Koha::Exceptions::MissingParameter', 'Exceptions thrown on missing parameter';

    is( "$@", "Required parameter 'name' missing", "Expected exception message" );

    throws_ok {
        Koha::Configurations->set_config(
            {
                library_id  => $library_id,
                category_id => $category_id,
                item_type   => $item_type,
                name        => $name,
            }
        );
    } 'Koha::Exceptions::MissingParameter', 'Exceptions thrown on missing parameter';

    is( "$@", "Required parameter 'value' missing", "Expected exception message" );

    $schema->storage->txn_rollback;
};
