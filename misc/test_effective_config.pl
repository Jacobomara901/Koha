#!/usr/bin/perl

use Modern::Perl;
use FindBin;
use lib "$FindBin::Bin/..";
use Koha::Database;
use Koha::Configuration;
use Koha::Configurations;
use Try::Tiny;
use Data::Dumper;

print "Testing Koha Configuration Effective Config\n";
print "=========================================\n\n";

# Create or connect to the test database
my $schema = Koha::Database->new->schema;

# Clean up existing test data
print "Cleaning up existing test configs...\n";
# $schema->txn_begin;
Koha::Configurations->search({ name => { -like => 'test_effective%' } })->delete;

# Create test configuration entries with different specificity levels
print "Creating test configurations...\n";

# Global config
my $global_config = Koha::Configuration->new({
    name => 'test_effective_setting',
    value => 'global value',
    type => 'text',
})->store;
print "Created global config with ID " . $global_config->id . "\n";

# Library-specific config
my $cpw = Koha::Libraries->find('CPL');
if ($cpw) {
    try {
        my $library_config = Koha::Configuration->new({
            name => 'test_effective_setting',
            library_id => 'CPL',
            value => 'library value',
            type => 'text',
        })->store;
        print "Created library-specific config with ID " . $library_config->id . "\n";
    } catch {
        print "Error creating library config: $_\n";
    };
}

# Category-specific config
my $pt = Koha::Patron::Categories->find('PT');
if ($pt) {
    try {
        my $category_config = Koha::Configuration->new({
            name => 'test_effective_setting',
            category_id => 'PT',
            value => 'category value',
            type => 'text',
        })->store;
        print "Created category-specific config with ID " . $category_config->id . "\n";
    } catch {
        print "Error creating category config: $_\n";
    };
}

# ItemType-specific config
my $bk = Koha::ItemTypes->find('BK');
if ($bk) {
    try {
        my $itemtype_config = Koha::Configuration->new({
            name => 'test_effective_setting',
            item_type => 'BK',
            value => 'itemtype value',
            type => 'text',
        })->store;
        print "Created itemtype-specific config with ID " . $itemtype_config->id . "\n";
    } catch {
        print "Error creating itemtype config: $_\n";
    };
}

# Test retrieving effective configurations
print "\nTesting effective configuration retrieval:\n";

# Test 1: Get effective global config when no specifics provided
my $effective = Koha::Configurations->get_effective_config({
    name => 'test_effective_setting',
    with_metadata => 1  # Explicitly request metadata for tests 1-9
});
print "Test 1: Effective global config:\n";
print "  Level: " . ($effective ? $effective->{level} : "not found") . "\n";
print "  Value: " . ($effective && $effective->{config} ? $effective->{config}->value : "not found") . "\n";

# Test 2: Get effective config for library
$effective = Koha::Configurations->get_effective_config({
    name => 'test_effective_setting',
    library_id => 'CPL',
    with_metadata => 1
});
print "\nTest 2: Effective config for CPL library:\n";
print "  Level: " . ($effective ? $effective->{level} : "not found") . "\n";
print "  Value: " . ($effective && $effective->{config} ? $effective->{config}->value : "not found") . "\n";

# Test 3: Get effective config for category
$effective = Koha::Configurations->get_effective_config({
    name => 'test_effective_setting',
    category_id => 'PT',
    with_metadata => 1
});
print "\nTest 3: Effective config for PT category:\n";
print "  Level: " . ($effective ? $effective->{level} : "not found") . "\n";
print "  Value: " . ($effective && $effective->{config} ? $effective->{config}->value : "not found") . "\n";

# Test 4: Get effective config for item type
$effective = Koha::Configurations->get_effective_config({
    name => 'test_effective_setting',
    item_type => 'BK',
    with_metadata => 1
});
print "\nTest 4: Effective config for BK item type:\n";
print "  Level: " . ($effective ? $effective->{level} : "not found") . "\n";
print "  Value: " . ($effective && $effective->{config} ? $effective->{config}->value : "not found") . "\n";

# Test 5: Get effective config for a library without a specific config
$effective = Koha::Configurations->get_effective_config({
    name => 'test_effective_setting',
    library_id => 'MPL', # Assuming this library doesn't have a specific config
    with_metadata => 1
});
print "\nTest 5: Effective config for MPL library (should fall back to global):\n";
print "  Level: " . ($effective ? $effective->{level} : "not found") . "\n";
print "  Value: " . ($effective && $effective->{config} ? $effective->{config}->value : "not found") . "\n";

# Test 6: Get effective config for a non-existent setting
$effective = Koha::Configurations->get_effective_config({
    name => 'test_effective_nonexistent',
    library_id => 'CPL',
    with_metadata => 1
});
print "\nTest 6: Effective config for non-existent setting:\n";
print "  Result: " . ($effective ? "Found (error!)" : "Not found (correct)") . "\n";

print "\n=== Testing specificity priority ===\n";

# Test 7: When providing both library_id and item_type, it should return the library-specific config
# since library is higher priority than item_type
$effective = Koha::Configurations->get_effective_config({
    name => 'test_effective_setting',
    library_id => 'CPL',
    item_type => 'BK',
    with_metadata => 1
});
print "\nTest 7: Effective config when both library and item_type provided:\n";
print "  Level: " . ($effective ? $effective->{level} : "not found") . "\n";
print "  Value: " . ($effective && $effective->{config} ? $effective->{config}->value : "not found") . "\n";
print "  Expected: 'library' level with 'library value'\n";

# Test 8: When providing category_id and item_type, it should return the category-specific config
$effective = Koha::Configurations->get_effective_config({
    name => 'test_effective_setting',
    category_id => 'PT',
    item_type => 'BK',
    with_metadata => 1
});
print "\nTest 8: Effective config when both category and item_type provided:\n";
print "  Level: " . ($effective ? $effective->{level} : "not found") . "\n";
print "  Value: " . ($effective && $effective->{config} ? $effective->{config}->value : "not found") . "\n";
print "  Expected: 'category' level with 'category value'\n";

# Test 9: When providing library_id, category_id, and item_type, it should return the library-specific config
$effective = Koha::Configurations->get_effective_config({
    name => 'test_effective_setting',
    library_id => 'CPL',
    category_id => 'PT',
    item_type => 'BK',
    with_metadata => 1
});
print "\nTest 9: Effective config when all three specificity levels provided:\n";
print "  Level: " . ($effective ? $effective->{level} : "not found") . "\n";
print "  Value: " . ($effective && $effective->{config} ? $effective->{config}->value : "not found") . "\n";
print "  Expected: 'library' level with 'library value'\n";

print "\n=== Testing with_metadata parameter ===\n";

# Test 10: Get config without metadata (default)
my $config_no_meta = Koha::Configurations->get_effective_config({
    name => 'test_effective_setting',
    library_id => 'CPL'
    # with_metadata defaults to 0
});
print "\nTest 10: Get config without metadata (default):\n";
print "  Result type: " . (ref($config_no_meta) || "undefined") . "\n";
print "  Is complete config object? " . (ref($config_no_meta) eq 'Koha::Configuration' ? "Yes" : "No") . "\n";
print "  Value: " . ($config_no_meta ? $config_no_meta->value : "not available") . "\n";

# Test 11: Get config with metadata explicitly set
my $config_with_meta = Koha::Configurations->get_effective_config({
    name => 'test_effective_setting',
    library_id => 'CPL',
    with_metadata => 1
});
print "\nTest 11: Get config with metadata explicitly set:\n";
print "  Result type: " . (ref($config_with_meta) || "undefined") . "\n";
print "  Has level info? " . (exists $config_with_meta->{level} ? "Yes" : "No") . "\n";
print "  Level: " . ($config_with_meta ? $config_with_meta->{level} : "not available") . "\n";
print "  Value: " . ($config_with_meta && $config_with_meta->{config} ? $config_with_meta->{config}->value : "not available") . "\n";

# Clean up
# $schema->txn_rollback;
print "\nTest data cleaned up.\n";
