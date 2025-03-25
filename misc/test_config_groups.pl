#!/usr/bin/perl

use Modern::Perl;
use FindBin;
use lib "$FindBin::Bin/..";
use Koha::Database;
use Koha::Configuration;
use Koha::Configurations;
use Koha::ConfigurationGroup;
use Koha::ConfigurationGroups;
use Try::Tiny;
use Data::Dumper;

# This script tests functionality of configuration groups and related methods

print "Testing Configuration Groups\n";
print "==========================\n\n";

# Create or connect to the test database
my $schema = Koha::Database->new->schema;

# Start a transaction so our test data doesn't persist
$schema->txn_begin;

# Clean up existing test data
print "Cleaning up existing test data...\n";
Koha::Configurations->search({ name => { -like => 'test_group_%' } })->delete;
Koha::ConfigurationGroups->search({ flag => 'TEST_GROUP' })->delete;

# Test 1: Create a configuration group
print "\nTest 1: Create a configuration group\n";
my $group = Koha::ConfigurationGroup->new({
    bit => 1024, # Choose a bit that's unlikely to be used
    flag => 'TEST_GROUP',
    flagdesc => 'Test Configuration Group',
})->store;

print "Created configuration group with flag: " . $group->flag . "\n";

# Test 2: Create configurations in this group
print "\nTest 2: Create configurations in this group\n";
my $config1 = Koha::Configuration->new({
    name => 'test_group_setting1',
    value => 'value1',
    type => 'text',
    configuration_group_bit => $group->bit,
})->store;
print "Created config1 with ID " . $config1->id . "\n";

my $config2 = Koha::Configuration->new({
    name => 'test_group_setting2',
    value => 'value2',
    type => 'text',
    configuration_group_bit => $group->bit,
})->store;
print "Created config2 with ID " . $config2->id . "\n";

# Test 3: Create a scoped configuration in this group
print "\nTest 3: Create a library-specific configuration in this group\n";
my $library = Koha::Libraries->find({ branchcode => 'CPL' });
if ($library) {
    my $library_config = Koha::Configuration->new({
        name => 'test_group_setting1',
        library_id => $library->branchcode,
        value => 'library value',
        type => 'text',
        configuration_group_bit => $group->bit,
    })->store;
    print "Created library-specific config with ID " . $library_config->id . "\n";
} else {
    print "Skipped - No CPL library found\n";
}

# Test 4: Test by_group method
print "\nTest 4: Test getting all configurations by group\n";
my $configs = Koha::Configurations->by_group($group->bit);
print "Found " . $configs->count . " configurations in group\n";
print "Configuration names: ";
my @names;
while (my $c = $configs->next) {
    push @names, $c->name;
}
print join(", ", @names) . "\n";

# Test 5: Test group_setting_names method
print "\nTest 5: Test getting distinct setting names from group\n";
my $names = Koha::Configurations->group_setting_names($group->bit);
print "Distinct setting names: " . join(", ", @$names) . "\n";
print "Number of distinct names: " . scalar(@$names) . " (expected 2)\n";

# Test 6: Test find_by_flag method
print "\nTest 6: Test finding a group by flag name\n";
my $found_group = Koha::ConfigurationGroups->find_by_flag('TEST_GROUP');
if ($found_group) {
    print "Found group: " . $found_group->flagdesc . "\n";
    print "Bit: " . $found_group->bit . "\n";
} else {
    print "ERROR: Group not found by flag name\n";
}

# Test 7: Test by_group_name method
print "\nTest 7: Test getting configurations by group name\n";
my $configs_by_name = Koha::Configurations->by_group_name('TEST_GROUP');
print "Found " . $configs_by_name->count . " configurations using group name\n";

# Test 8: Test group_setting_names_by_flag method
print "\nTest 8: Test getting distinct setting names by group flag\n";
my $names_by_flag = Koha::Configurations->group_setting_names_by_flag('TEST_GROUP');
print "Distinct setting names by flag: " . join(", ", @$names_by_flag) . "\n";

# Test 9: Test with non-existent group flag
print "\nTest 9: Test with non-existent group flag\n";
my $non_existent = Koha::Configurations->group_setting_names_by_flag('NON_EXISTENT_GROUP');
print "Result for non-existent group: " . (defined $non_existent ? "Error - returned something" : "Success - returned undef") . "\n";

# Clean up our test data
$schema->txn_rollback;
print "\nTest data cleaned up.\n";
