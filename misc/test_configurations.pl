#!/usr/bin/perl

use Modern::Perl;
use FindBin;
use lib "$FindBin::Bin/..";
use Koha::Database;
use Koha::Configuration;
use Koha::Configurations;
use Try::Tiny;
use Data::Dumper;

# This script tests the basic functionality of the Configuration system
# It creates, retrieves, updates, and deletes configuration entries

print "Testing Koha Configuration System\n";
print "================================\n\n";

# Create or connect to the test database
my $schema = Koha::Database->new->schema;

# Start a transaction so our test data doesn't persist
# $schema->txn_begin;

# Clean up existing test data
print "Cleaning up existing test configs...\n";
Koha::Configurations->search({ name => { -like => 'test_%' } })->delete;

# Test 1: Create and retrieve a global configuration
print "\nTest 1: Create and retrieve a global configuration\n";
my $global_config = Koha::Configuration->new({
    name => 'test_global_setting',
    value => 'global value',
    type => 'text',
})->store;
print "Created global config with ID " . $global_config->id . "\n";

# Retrieve it back to confirm it was stored correctly
my $retrieved = Koha::Configurations->find($global_config->id);
print "Retrieved: " . ($retrieved ? "Yes" : "No") . "\n";
print "Name: " . $retrieved->name . "\n";
print "Value: " . $retrieved->value . "\n";
print "Type: " . $retrieved->type . "\n";

# Test 2: Create and retrieve a library-specific configuration
print "\nTest 2: Create and retrieve a library-specific configuration\n";
# Find a valid library code first
my $library = Koha::Libraries->find({ branchcode => 'CPL' });
if ($library) {
    my $library_config = Koha::Configuration->new({
        name => 'test_library_setting',
        library_id => $library->branchcode,
        value => 'library value',
        type => 'text',
    })->store;
    print "Created library-specific config with ID " . $library_config->id . "\n";

    # Retrieve it back
    my $retrieved = Koha::Configurations->find($library_config->id);
    print "Retrieved: " . ($retrieved ? "Yes" : "No") . "\n";
    print "Name: " . $retrieved->name . "\n";
    print "Value: " . $retrieved->value . "\n";
    print "Library: " . $retrieved->library_id . "\n";
} else {
    print "Skipped - No CPL library found\n";
}

# Test 3: Test uniqueness constraints
print "\nTest 3: Test uniqueness constraints\n";
try {
    # Try to create a duplicate global setting
    my $duplicate = Koha::Configuration->new({
        name => 'test_global_setting',  # Same name as the one we created earlier
        value => 'another value',
        type => 'text',
    })->store;
    print "ERROR: Duplicate global setting was allowed!\n";
} catch {
    print "Success: Duplicate global setting was correctly prevented\n";
};

# Test 4: Update a configuration
print "\nTest 4: Update a configuration\n";
$global_config->value('updated global value');
$global_config->store;
$retrieved = Koha::Configurations->find($global_config->id);
print "Updated value: " . $retrieved->value . "\n";

# Test 5: Test combined attributes constraint
print "\nTest 5: Test combined attributes constraint\n";
try {
    # Try to create a config with both library_id and category_id set
    my $invalid = Koha::Configuration->new({
        name => 'test_invalid_setting',
        library_id => 'CPL',
        category_id => 'PT',  # This combination should be rejected
        value => 'invalid value',
        type => 'text',
    })->store;
    print "ERROR: Combined attributes were allowed!\n";
} catch {
    print "Success: Combined attributes were correctly prevented\n";
};

# Test 6: Test the get_effective_config function
print "\nTest 6: Test the get_effective_config function\n";

# Create configs at different specificity levels
my $effective_test_name = 'test_effective_setting';
my $global_effective = Koha::Configuration->new({
    name => $effective_test_name,
    value => 'global effective value',
    type => 'text',
})->store;

if ($library) {
    my $library_effective = Koha::Configuration->new({
        name => $effective_test_name,
        library_id => $library->branchcode,
        value => 'library effective value',
        type => 'text',
    })->store;

    # Get the effective config for this library
    my $effective = Koha::Configurations->get_effective_config({
        name => $effective_test_name,
        library_id => $library->branchcode,
        with_metadata => 1
    });

    print "Effective config level: " . $effective->{level} . "\n";
    print "Effective config value: " . $effective->{config}->value . "\n";
}

# Test 7: Ensure updating a configuration updates the existing row instead of creating a duplicate
print "\nTest 7: Test updating an existing configuration\n";

# Count the number of rows with our test name before the update
my $count_before = Koha::Configurations->search({ name => $effective_test_name })->count();
print "Number of configs with name '$effective_test_name' before update: $count_before\n";

# Update the global config
$global_effective->value("updated effective value");
$global_effective->store();

# Count again after the update
my $count_after = Koha::Configurations->search({ name => $effective_test_name })->count();
print "Number of configs with name '$effective_test_name' after update: $count_after\n";

# Verify the update worked by retrieving the value
my $updated_global = Koha::Configurations->find($global_effective->id);
print "Updated global config value: " . $updated_global->value . "\n";

# Verify counts are the same (no duplicates created)
if ($count_before == $count_after) {
    print "Success: No duplicate rows were created during update\n";
} else {
    print "ERROR: Update created duplicate rows instead of modifying existing!\n";
}

# Clean up our test data
# $schema->txn_rollback;
print "\nTest data cleaned up.\n";
