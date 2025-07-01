#!/usr/bin/perl

# Toggle messaging preferences between print and email for testing
# Usage: perl toggle_messaging_preference.pl <borrowernumber> <transport_type>
# where transport_type is either 'print' or 'email'

use Modern::Perl;
use C4::Context;
use Koha::Patrons;

# Get parameters
my $borrowernumber = shift || die "Usage: perl toggle_messaging_preference.pl <borrowernumber> <transport_type>\n";
my $transport_type = shift || die "Usage: perl toggle_messaging_preference.pl <borrowernumber> <transport_type>\nTransport type must be 'print' or 'email'\n";

unless ($transport_type eq 'print' || $transport_type eq 'email') {
    die "Transport type must be 'print' or 'email', got: $transport_type\n";
}

my $dbh = C4::Context->dbh;

# Verify borrower exists
my $patron = Koha::Patrons->find($borrowernumber);
unless ($patron) {
    die "Borrower $borrowernumber not found\n";
}

print "Updating messaging preferences for borrower $borrowernumber: " . $patron->firstname . " " . $patron->surname . "\n";
print "Setting Item_Due notices to use: $transport_type transport\n";

# Get the message_attribute_id for 'Item_Due'
my $item_due_attr_id = $dbh->selectrow_array(q{
    SELECT message_attribute_id
    FROM message_attributes
    WHERE message_name = 'Item_Due'
});

unless ($item_due_attr_id) {
    die "Item_Due message attribute not found. Run setup_test_due_notice.pl first.\n";
}

# Remove existing transport preferences for this borrower and message type
$dbh->do(q{
    DELETE bmtp FROM borrower_message_transport_preferences bmtp
    JOIN borrower_message_preferences bmp ON bmtp.borrower_message_preference_id = bmp.borrower_message_preference_id
    WHERE bmp.borrowernumber = ? AND bmp.message_attribute_id = ?
}, undef, $borrowernumber, $item_due_attr_id);

# Get the borrower_message_preference_id (should exist from setup script)
my $pref_id = $dbh->selectrow_array(q{
    SELECT borrower_message_preference_id
    FROM borrower_message_preferences
    WHERE borrowernumber = ? AND message_attribute_id = ?
}, undef, $borrowernumber, $item_due_attr_id);

unless ($pref_id) {
    die "No messaging preference found for borrower $borrowernumber and Item_Due. Run setup_test_due_notice.pl first.\n";
}

# Add the new transport preference
$dbh->do(q{
    INSERT INTO borrower_message_transport_preferences (borrower_message_preference_id, message_transport_type)
    VALUES (?, ?)
}, undef, $pref_id, $transport_type);

print "✓ Updated messaging preference: Item_Due notices will now use $transport_type transport\n";

# Show current preferences for verification
my $current_prefs = $dbh->selectall_arrayref(q{
    SELECT bmtp.message_transport_type
    FROM borrower_message_preferences bmp
    JOIN borrower_message_transport_preferences bmtp ON bmp.borrower_message_preference_id = bmtp.borrower_message_preference_id
    JOIN message_attributes ma ON bmp.message_attribute_id = ma.message_attribute_id
    WHERE bmp.borrowernumber = ? AND ma.message_name = 'Item_Due'
}, { Slice => {} }, $borrowernumber);

print "Current Item_Due transport preferences: " . join(', ', map { $_->{message_transport_type} } @$current_prefs) . "\n";

print "\nNext steps:\n";
if ($transport_type eq 'print') {
    print "1. Create/use an overdue item for borrower $borrowernumber\n";
    print "2. Run: misc/cronjobs/advance_notices.pl -c\n";
    print "3. Run: misc/cronjobs/gather_print_notices.pl\n";
    print "4. Check for charges: SELECT * FROM accountlines WHERE borrowernumber = $borrowernumber AND debit_type_code = 'PRINT_NOTICE';\n";
} else {
    print "1. Create/use an overdue item for borrower $borrowernumber\n";
    print "2. Run: misc/cronjobs/advance_notices.pl -c\n";
    print "3. Run: misc/cronjobs/gather_print_notices.pl (should not process email notices)\n";
    print "4. Verify no new print charges created\n";
    print "5. Check email queue: SELECT * FROM message_queue WHERE borrowernumber = $borrowernumber AND message_transport_type = 'email';\n";
}

print "\nDone!\n";