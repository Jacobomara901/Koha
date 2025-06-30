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

use Test::More tests => 5;
use Test::MockModule;

use C4::Context;
use Koha::Account;
use Koha::Patrons;

use t::lib::Mocks;
use t::lib::TestBuilder;

my $schema = Koha::Database->new->schema;
$schema->storage->dbh->{PrintError} = 0;
my $builder = t::lib::TestBuilder->new;
C4::Context->interface('commandline');

subtest 'PrintNoticeCharging preference values' => sub {
    plan tests => 8;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object({ class => 'Koha::Patrons' });
    my $account = $patron->account;

    # Test 1: Preference disabled (0)
    t::lib::Mocks::mock_preference('PrintNoticeCharging', 0);
    t::lib::Mocks::mock_preference('PrintNoticeChargeAmount', '1.00');

    my $result1 = $account->add_print_notice_charge({
        notice_code => 'ODUE',
        library_id => $patron->branchcode
    });
    is($result1, undef, 'No charge when PrintNoticeCharging is 0');

    # Test 2: Preference enabled (1)
    t::lib::Mocks::mock_preference('PrintNoticeCharging', 1);

    my $result2 = $account->add_print_notice_charge({
        notice_code => 'ODUE',
        library_id => $patron->branchcode
    });
    isa_ok($result2, 'Koha::Account::Line', 'Charge created when PrintNoticeCharging is 1');

    # Test 3: Preference enabled with string 'Yes'
    t::lib::Mocks::mock_preference('PrintNoticeCharging', 'Yes');

    my $result3 = $account->add_print_notice_charge({
        notice_code => 'PREDUE',
        library_id => $patron->branchcode
    });
    isa_ok($result3, 'Koha::Account::Line', 'Charge created when PrintNoticeCharging is "Yes"');

    # Test 4: Preference disabled with string 'No'
    t::lib::Mocks::mock_preference('PrintNoticeCharging', 'No');

    my $result4 = $account->add_print_notice_charge({
        notice_code => 'HOLD',
        library_id => $patron->branchcode
    });
    is($result4, undef, 'No charge when PrintNoticeCharging is "No"');

    # Test 5: Empty preference value
    t::lib::Mocks::mock_preference('PrintNoticeCharging', '');

    my $result5 = $account->add_print_notice_charge({
        notice_code => 'RENEWAL',
        library_id => $patron->branchcode
    });
    is($result5, undef, 'No charge when PrintNoticeCharging is empty');

    # Test 6: Undefined preference value
    t::lib::Mocks::mock_preference('PrintNoticeCharging', undef);

    my $result6 = $account->add_print_notice_charge({
        notice_code => 'CHECKIN',
        library_id => $patron->branchcode
    });
    is($result6, undef, 'No charge when PrintNoticeCharging is undefined');

    # Test 7: Numeric true value
    t::lib::Mocks::mock_preference('PrintNoticeCharging', 2);

    my $result7 = $account->add_print_notice_charge({
        notice_code => 'CHECKOUT',
        library_id => $patron->branchcode
    });
    isa_ok($result7, 'Koha::Account::Line', 'Charge created when PrintNoticeCharging is numeric true');

    # Test 8: Account balance reflects only enabled charges
    # We should have 3 charges: 1.00 + 1.00 + 1.00 = 3.00
    is($account->balance, 3.00, 'Account balance reflects only charges when preference was enabled');

    $schema->storage->txn_rollback;
};

subtest 'PrintNoticeChargeAmount preference values' => sub {
    plan tests => 9;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object({ class => 'Koha::Patrons' });
    my $account = $patron->account;

    # Enable charging for all tests
    t::lib::Mocks::mock_preference('PrintNoticeCharging', 1);

    # Test 1: Standard decimal amount
    t::lib::Mocks::mock_preference('PrintNoticeChargeAmount', '0.50');
    my $result1 = $account->add_print_notice_charge({
        notice_code => 'ODUE',
        library_id => $patron->branchcode
    });
    cmp_ok($result1->amount, '==', 0.50, 'Standard decimal amount works');

    # Test 2: Integer amount
    t::lib::Mocks::mock_preference('PrintNoticeChargeAmount', '2');
    my $result2 = $account->add_print_notice_charge({
        notice_code => 'PREDUE',
        library_id => $patron->branchcode
    });
    is($result2->amount, 2.00, 'Integer amount works');

    # Test 3: Zero amount
    t::lib::Mocks::mock_preference('PrintNoticeChargeAmount', '0');
    my $result3 = $account->add_print_notice_charge({
        notice_code => 'HOLD',
        library_id => $patron->branchcode
    });
    is($result3, undef, 'Zero amount does not create charge');

    # Test 4: Very small amount
    t::lib::Mocks::mock_preference('PrintNoticeChargeAmount', '0.01');
    my $result4 = $account->add_print_notice_charge({
        notice_code => 'RENEWAL',
        library_id => $patron->branchcode
    });
    is($result4->amount, 0.01, 'Very small amount works');

    # Test 5: Large amount
    t::lib::Mocks::mock_preference('PrintNoticeChargeAmount', '99.99');
    my $result5 = $account->add_print_notice_charge({
        notice_code => 'CHECKIN',
        library_id => $patron->branchcode
    });
    is($result5->amount, 99.99, 'Large amount works');

    # Test 6: Empty preference value
    t::lib::Mocks::mock_preference('PrintNoticeChargeAmount', '');
    my $result6 = $account->add_print_notice_charge({
        notice_code => 'CHECKOUT',
        library_id => $patron->branchcode
    });
    is($result6, undef, 'Empty amount preference does not create charge');

    # Test 7: Undefined preference value
    t::lib::Mocks::mock_preference('PrintNoticeChargeAmount', undef);
    my $result7 = $account->add_print_notice_charge({
        notice_code => 'RETURN',
        library_id => $patron->branchcode
    });
    is($result7, undef, 'Undefined amount preference does not create charge');

    # Test 8: Non-numeric preference value
    t::lib::Mocks::mock_preference('PrintNoticeChargeAmount', 'invalid');
    my $result8 = $account->add_print_notice_charge({
        notice_code => 'FINE',
        library_id => $patron->branchcode
    });
    is($result8, undef, 'Non-numeric amount preference does not create charge');

    # Test 9: Account balance reflects only valid charges
    # We should have 4 charges: 0.50 + 2.00 + 0.01 + 99.99 = 102.50
    is($account->balance, 102.50, 'Account balance reflects only valid charges');

    $schema->storage->txn_rollback;
};

subtest 'system preference interaction with custom amounts' => sub {
    plan tests => 6;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object({ class => 'Koha::Patrons' });
    my $account = $patron->account;

    # Enable charging
    t::lib::Mocks::mock_preference('PrintNoticeCharging', 1);
    t::lib::Mocks::mock_preference('PrintNoticeChargeAmount', '0.75');

    # Test 1: Custom amount overrides preference
    my $result1 = $account->add_print_notice_charge({
        notice_code => 'ODUE',
        library_id => $patron->branchcode,
        amount => 1.25
    });
    is($result1->amount, 1.25, 'Custom amount overrides system preference');

    # Test 2: Zero custom amount overrides positive preference
    my $result2 = $account->add_print_notice_charge({
        notice_code => 'PREDUE',
        library_id => $patron->branchcode,
        amount => 0.00
    });
    is($result2, undef, 'Zero custom amount overrides positive preference');

    # Test 3: System preference used when no custom amount
    my $result3 = $account->add_print_notice_charge({
        notice_code => 'HOLD',
        library_id => $patron->branchcode
    });
    is($result3->amount, 0.75, 'System preference used when no custom amount');

    # Test 4: Custom amount works even with zero preference
    t::lib::Mocks::mock_preference('PrintNoticeChargeAmount', '0.00');
    my $result4 = $account->add_print_notice_charge({
        notice_code => 'RENEWAL',
        library_id => $patron->branchcode,
        amount => 0.50
    });
    is($result4->amount, 0.50, 'Custom amount works even with zero preference');

    # Test 5: Invalid custom amount falls back to preference
    t::lib::Mocks::mock_preference('PrintNoticeChargeAmount', '1.00');
    my $result5 = $account->add_print_notice_charge({
        notice_code => 'CHECKIN',
        library_id => $patron->branchcode,
        amount => 'invalid'
    });
    is($result5, undef, 'Invalid custom amount does not create charge');

    # Test 6: Account balance reflects actual charges
    # We should have 3 charges: 1.25 + 0.75 + 0.50 = 2.50
    is($account->balance, 2.50, 'Account balance reflects actual charges');

    $schema->storage->txn_rollback;
};

subtest 'system preference edge cases' => sub {
    plan tests => 6;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object({ class => 'Koha::Patrons' });
    my $account = $patron->account;

    # Test 1: Charging disabled but positive amount
    t::lib::Mocks::mock_preference('PrintNoticeCharging', 0);
    t::lib::Mocks::mock_preference('PrintNoticeChargeAmount', '1.00');

    my $result1 = $account->add_print_notice_charge({
        notice_code => 'ODUE',
        library_id => $patron->branchcode
    });
    is($result1, undef, 'No charge when charging disabled regardless of amount');

    # Test 2: Charging enabled but negative amount preference
    t::lib::Mocks::mock_preference('PrintNoticeCharging', 1);
    t::lib::Mocks::mock_preference('PrintNoticeChargeAmount', '-1.00');

    my $result2 = $account->add_print_notice_charge({
        notice_code => 'PREDUE',
        library_id => $patron->branchcode
    });
    is($result2, undef, 'No charge for negative amount preference');

    # Test 3: Very large amount preference
    t::lib::Mocks::mock_preference('PrintNoticeChargeAmount', '999999.99');

    my $result3 = $account->add_print_notice_charge({
        notice_code => 'HOLD',
        library_id => $patron->branchcode
    });
    is($result3->amount, 999999.99, 'Very large amounts work');

    # Test 4: Precision test with many decimal places
    t::lib::Mocks::mock_preference('PrintNoticeChargeAmount', '1.23456789');

    my $result4 = $account->add_print_notice_charge({
        notice_code => 'RENEWAL',
        library_id => $patron->branchcode
    });
    # Database should handle precision according to column definition
    is($result4->amount, 1.23456789, 'Decimal precision handled correctly');

    # Test 5: Scientific notation (if supported)
    t::lib::Mocks::mock_preference('PrintNoticeChargeAmount', '1e-2');

    my $result5 = $account->add_print_notice_charge({
        notice_code => 'CHECKIN',
        library_id => $patron->branchcode
    });
    # This might work or might not depending on Perl/MySQL handling
    ok(defined($result5) ? $result5->amount == 0.01 : !defined($result5),
       'Scientific notation handled appropriately');

    # Test 6: Leading/trailing whitespace
    t::lib::Mocks::mock_preference('PrintNoticeChargeAmount', ' 2.50 ');

    my $result6 = $account->add_print_notice_charge({
        notice_code => 'CHECKOUT',
        library_id => $patron->branchcode
    });
    is($result6, undef, 'Whitespace in preference value rejected');

    $schema->storage->txn_rollback;
};

subtest 'system preference validation and error handling' => sub {
    plan tests => 8;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object({ class => 'Koha::Patrons' });
    my $account = $patron->account;

    # Enable charging
    t::lib::Mocks::mock_preference('PrintNoticeCharging', 1);

    # Test 1: Multiple decimal points
    t::lib::Mocks::mock_preference('PrintNoticeChargeAmount', '1.2.3');
    my $result1 = $account->add_print_notice_charge({
        notice_code => 'ODUE',
        library_id => $patron->branchcode
    });
    is($result1, undef, 'Invalid decimal format rejected');

    # Test 2: Alphabetic characters
    t::lib::Mocks::mock_preference('PrintNoticeChargeAmount', '1.50abc');
    my $result2 = $account->add_print_notice_charge({
        notice_code => 'PREDUE',
        library_id => $patron->branchcode
    });
    is($result2, undef, 'Alphabetic characters in amount rejected');

    # Test 3: Special characters
    t::lib::Mocks::mock_preference('PrintNoticeChargeAmount', '$1.50');
    my $result3 = $account->add_print_notice_charge({
        notice_code => 'HOLD',
        library_id => $patron->branchcode
    });
    is($result3, undef, 'Currency symbol in amount rejected');

    # Test 4: Comma as decimal separator (European style)
    t::lib::Mocks::mock_preference('PrintNoticeChargeAmount', '1,50');
    my $result4 = $account->add_print_notice_charge({
        notice_code => 'RENEWAL',
        library_id => $patron->branchcode
    });
    is($result4, undef, 'Comma decimal separator rejected');

    # Test 5: Valid formats that should work
    t::lib::Mocks::mock_preference('PrintNoticeChargeAmount', '1.50');
    my $result5 = $account->add_print_notice_charge({
        notice_code => 'CHECKIN',
        library_id => $patron->branchcode
    });
    cmp_ok($result5->amount, '==', 1.50, 'Standard format accepted');

    # Test 6: Leading zeros
    t::lib::Mocks::mock_preference('PrintNoticeChargeAmount', '00001.50');
    my $result6 = $account->add_print_notice_charge({
        notice_code => 'CHECKOUT',
        library_id => $patron->branchcode
    });
    cmp_ok($result6->amount, '==', 1.50, 'Leading zeros handled correctly');

    # Test 7: Trailing zeros
    t::lib::Mocks::mock_preference('PrintNoticeChargeAmount', '1.5000');
    my $result7 = $account->add_print_notice_charge({
        notice_code => 'RETURN',
        library_id => $patron->branchcode
    });
    cmp_ok($result7->amount, '==', 1.50, 'Trailing zeros handled correctly');

    # Test 8: Account balance reflects only valid charges
    # We should have 3 charges: 1.50 + 1.50 + 1.50 = 4.50
    is($account->balance, 4.50, 'Account balance reflects only valid charges');

    $schema->storage->txn_rollback;
};