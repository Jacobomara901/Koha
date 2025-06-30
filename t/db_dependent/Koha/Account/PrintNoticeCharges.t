#!/usr/bin/perl

# Copyright 2024 Koha Development team
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
# along with Koha; if not, see <http://www.gnu.org/licenses>

use Modern::Perl;

use Test::More tests => 7;
use Test::MockModule;
use Test::Exception;
use Test::Warn;

use C4::Context;
use Koha::Account;
use Koha::Account::Lines;
use Koha::Patrons;

use t::lib::Mocks;
use t::lib::TestBuilder;

my $schema = Koha::Database->new->schema;
$schema->storage->dbh->{PrintError} = 0;
my $builder = t::lib::TestBuilder->new;
C4::Context->interface('commandline');

subtest 'add_print_notice_charge with charging disabled' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;

    # Disable print notice charging
    t::lib::Mocks::mock_preference('PrintNoticeCharging', 0);
    t::lib::Mocks::mock_preference('PrintNoticeChargeAmount', '0.50');

    my $patron = $builder->build_object({ class => 'Koha::Patrons' });
    my $account = Koha::Account->new({ patron_id => $patron->borrowernumber });

    my $initial_balance = $account->balance;

    my $result = $account->add_print_notice_charge({
        notice_code => 'ODUE',
        library_id => $patron->branchcode
    });

    is($result, undef, 'No charge applied when charging disabled');
    is($account->balance, $initial_balance, 'Account balance unchanged');
    is($account->lines->count, 0, 'No account lines created');

    $schema->storage->txn_rollback;
};

subtest 'add_print_notice_charge with charging enabled' => sub {
    plan tests => 9;

    $schema->storage->txn_begin;

    # Enable print notice charging
    t::lib::Mocks::mock_preference('PrintNoticeCharging', 1);
    t::lib::Mocks::mock_preference('PrintNoticeChargeAmount', '0.75');

    my $patron = $builder->build_object({ class => 'Koha::Patrons' });
    my $account = Koha::Account->new({ patron_id => $patron->borrowernumber });

    my $initial_balance = $account->balance;

    my $result = $account->add_print_notice_charge({
        notice_code => 'ODUE',
        library_id => $patron->branchcode
    });

    isa_ok($result, 'Koha::Account::Line', 'Returns account line object');
    is($account->balance, $initial_balance + 0.75, 'Account balance increased by charge amount');
    is($result->debit_type_code, 'PRINT_NOTICE', 'Correct debit type applied');
    is($result->amount, 0.75, 'Correct amount charged');
    is($result->amountoutstanding, 0.75, 'Full amount outstanding');
    like($result->description, qr/Print notice/, 'Description contains "Print notice"');
    like($result->description, qr/ODUE/, 'Description includes notice code');
    is($result->borrowernumber, $patron->borrowernumber, 'Correct patron charged');
    is($result->interface, 'cron', 'Correct interface recorded');

    $schema->storage->txn_rollback;
};

subtest 'add_print_notice_charge with custom amount' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    # Enable print notice charging
    t::lib::Mocks::mock_preference('PrintNoticeCharging', 1);
    t::lib::Mocks::mock_preference('PrintNoticeChargeAmount', '0.50');

    my $patron = $builder->build_object({ class => 'Koha::Patrons' });
    my $account = Koha::Account->new({ patron_id => $patron->borrowernumber });

    my $custom_amount = 1.25;
    my $result = $account->add_print_notice_charge({
        notice_code => 'PREDUE',
        library_id => $patron->branchcode,
        amount => $custom_amount
    });

    isa_ok($result, 'Koha::Account::Line', 'Returns account line object');
    is($result->amount, $custom_amount, 'Custom amount used instead of system preference');
    is($account->balance, $custom_amount, 'Account balance reflects custom amount');
    like($result->description, qr/PREDUE/, 'Description includes notice code');

    $schema->storage->txn_rollback;
};

subtest 'add_print_notice_charge with zero amount' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;

    # Enable charging but set amount to zero
    t::lib::Mocks::mock_preference('PrintNoticeCharging', 1);
    t::lib::Mocks::mock_preference('PrintNoticeChargeAmount', '0.00');

    my $patron = $builder->build_object({ class => 'Koha::Patrons' });
    my $account = Koha::Account->new({ patron_id => $patron->borrowernumber });

    my $result = $account->add_print_notice_charge({
        notice_code => 'HOLD',
        library_id => $patron->branchcode
    });

    is($result, undef, 'No charge applied when amount is zero');
    is($account->balance, 0, 'Account balance unchanged');
    is($account->lines->count, 0, 'No account lines created');

    $schema->storage->txn_rollback;
};

subtest 'add_print_notice_charge validation tests' => sub {
    plan tests => 5;

    $schema->storage->txn_begin;

    # Enable print notice charging
    t::lib::Mocks::mock_preference('PrintNoticeCharging', 1);
    t::lib::Mocks::mock_preference('PrintNoticeChargeAmount', '0.50');

    my $patron = $builder->build_object({ class => 'Koha::Patrons' });
    my $account = Koha::Account->new({ patron_id => $patron->borrowernumber });

    # Test with invalid negative amount
    warning_like {
        my $result = $account->add_print_notice_charge({
            notice_code => 'ODUE',
            library_id => $patron->branchcode,
            amount => -0.50
        });
        is($result, undef, 'No charge applied for negative amount');
    } qr/Invalid print notice charge amount/, 'Warning generated for negative amount';

    # Test with invalid non-numeric amount
    warning_like {
        my $result = $account->add_print_notice_charge({
            notice_code => 'ODUE',
            library_id => $patron->branchcode,
            amount => 'invalid'
        });
        is($result, undef, 'No charge applied for non-numeric amount');
    } qr/Invalid print notice charge amount/, 'Warning generated for non-numeric amount';

    # Test with valid amount works
    my $result = $account->add_print_notice_charge({
        notice_code => 'ODUE',
        library_id => $patron->branchcode,
        amount => 1.00
    });
    isa_ok($result, 'Koha::Account::Line', 'Valid amount works correctly');

    $schema->storage->txn_rollback;
};

subtest 'add_print_notice_charge without notice code' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;

    # Enable print notice charging
    t::lib::Mocks::mock_preference('PrintNoticeCharging', 1);
    t::lib::Mocks::mock_preference('PrintNoticeChargeAmount', '0.50');

    my $patron = $builder->build_object({ class => 'Koha::Patrons' });
    my $account = Koha::Account->new({ patron_id => $patron->borrowernumber });

    my $result = $account->add_print_notice_charge({
        library_id => $patron->branchcode
    });

    isa_ok($result, 'Koha::Account::Line', 'Returns account line object even without notice code');
    is($result->description, 'Print notice', 'Description is generic without notice code');
    cmp_ok($result->amount, '==', 0.50, 'System preference amount used');

    $schema->storage->txn_rollback;
};

subtest 'add_print_notice_charge library_id handling' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    # Enable print notice charging
    t::lib::Mocks::mock_preference('PrintNoticeCharging', 1);
    t::lib::Mocks::mock_preference('PrintNoticeChargeAmount', '0.50');

    my $patron = $builder->build_object({ class => 'Koha::Patrons' });
    my $account = Koha::Account->new({ patron_id => $patron->borrowernumber });

    # Get the patron's library for testing
    my $patron_library = $patron->branchcode;

    # Mock userenv for default library
    my $mock_context = Test::MockModule->new('C4::Context');
    $mock_context->mock('userenv', sub {
        return { branch => $patron_library };
    });

    # Test with explicit library_id
    my $result1 = $account->add_print_notice_charge({
        notice_code => 'ODUE',
        library_id => $patron_library
    });
    is($result1->branchcode, $patron_library, 'Explicit library_id used when provided');

    # Test without library_id (should use userenv)
    my $result2 = $account->add_print_notice_charge({
        notice_code => 'PREDUE'
    });
    is($result2->branchcode, $patron_library, 'Default library from userenv used when not provided');

    # Test with undefined userenv
    $mock_context->mock('userenv', sub { return undef; });
    my $result3 = $account->add_print_notice_charge({
        notice_code => 'HOLD'
    });
    isa_ok($result3, 'Koha::Account::Line', 'Still works with undefined userenv');
    is($result3->branchcode, undef, 'Library_id is undef when no userenv');

    $schema->storage->txn_rollback;
};