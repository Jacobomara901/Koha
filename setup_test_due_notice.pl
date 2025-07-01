#!/usr/bin/perl

# Test script to set up a due notice for borrower 2
# This allows testing the print notice charging feature

use Modern::Perl;
use DateTime;
use C4::Context;
use C4::Letters;
use Koha::Database;
use Koha::Patrons;

my $dbh = C4::Context->dbh;

# Borrower number to test with
my $borrowernumber = 2;

# Check if borrower exists
my $patron = Koha::Patrons->find($borrowernumber);
unless ($patron) {
    die "Borrower $borrowernumber not found in database\n";
}

print "Setting up test due notice for borrower $borrowernumber: " . $patron->firstname . " " . $patron->surname . "\n";

# Check current messaging preferences
my $current_prefs = $dbh->selectall_arrayref(q{
    SELECT bmp.*, bmtp.message_transport_type
    FROM borrower_message_preferences bmp
    LEFT JOIN borrower_message_transport_preferences bmtp ON bmp.borrower_message_preference_id = bmtp.borrower_message_preference_id
    LEFT JOIN message_attributes ma ON bmp.message_attribute_id = ma.message_attribute_id
    WHERE bmp.borrowernumber = ? AND ma.message_name = 'Item_Due'
}, { Slice => {} }, $borrowernumber);

print "Current messaging preferences for Item_Due: " . (@$current_prefs ? scalar(@$current_prefs) . " found" : "none") . "\n";

# Set up messaging preferences for due notices with print transport
# First, get the message_attribute_id for 'Item_Due'
my $item_due_attr_id = $dbh->selectrow_array(q{
    SELECT message_attribute_id
    FROM message_attributes
    WHERE message_name = 'Item_Due'
});

unless ($item_due_attr_id) {
    # Create the Item_Due message attribute if it doesn't exist
    $dbh->do(q{
        INSERT INTO message_attributes (message_name, takes_days)
        VALUES ('Item_Due', 0)
    });
    $item_due_attr_id = $dbh->last_insert_id(undef, undef, 'message_attributes', 'message_attribute_id');
    print "✓ Created Item_Due message attribute (ID: $item_due_attr_id)\n";
}

# Ensure message transport exists for Item_Due + print
my $transport_exists = $dbh->selectrow_array(q{
    SELECT COUNT(*)
    FROM message_transports
    WHERE message_attribute_id = ?
    AND message_transport_type = 'print'
    AND letter_module = 'circulation'
    AND letter_code = 'DUE'
}, undef, $item_due_attr_id);

unless ($transport_exists) {
    $dbh->do(q{
        INSERT INTO message_transports (message_attribute_id, message_transport_type, is_digest, letter_module, letter_code, branchcode)
        VALUES (?, 'print', 0, 'circulation', 'DUE', '')
    }, undef, $item_due_attr_id);
    print "✓ Created message transport mapping for Item_Due -> DUE (print)\n";
}

# Remove any existing preferences for this borrower and message type
$dbh->do(q{
    DELETE bmtp FROM borrower_message_transport_preferences bmtp
    JOIN borrower_message_preferences bmp ON bmtp.borrower_message_preference_id = bmp.borrower_message_preference_id
    WHERE bmp.borrowernumber = ? AND bmp.message_attribute_id = ?
}, undef, $borrowernumber, $item_due_attr_id);

$dbh->do(q{
    DELETE FROM borrower_message_preferences
    WHERE borrowernumber = ? AND message_attribute_id = ?
}, undef, $borrowernumber, $item_due_attr_id);

# Create new messaging preference for due notices
my $sth = $dbh->prepare(q{
    INSERT INTO borrower_message_preferences (borrowernumber, message_attribute_id, days_in_advance, wants_digest)
    VALUES (?, ?, 0, 0)
});
$sth->execute($borrowernumber, $item_due_attr_id);
my $pref_id = $dbh->last_insert_id(undef, undef, 'borrower_message_preferences', 'borrower_message_preference_id');

# Add both print and email transport preferences
$dbh->do(q{
    INSERT INTO borrower_message_transport_preferences (borrower_message_preference_id, message_transport_type)
    VALUES (?, 'print'), (?, 'email')
}, undef, $pref_id, $pref_id);

print "✓ Set up messaging preferences for borrower $borrowernumber: Item_Due -> print AND email transports\n";

# Ensure 'print' and 'email' message transport types exist
foreach my $transport ('print', 'email') {
    my $transport_exists = $dbh->selectrow_array(q{
        SELECT COUNT(*) FROM message_transport_types WHERE message_transport_type = ?
    }, undef, $transport);

    unless ($transport_exists) {
        $dbh->do(q{
            INSERT INTO message_transport_types (message_transport_type) VALUES (?)
        }, undef, $transport);
        print "✓ Created '$transport' message transport type\n";
    }
}

# Ensure there's a DUE letter template for print
my $letter_exists = $dbh->selectrow_array(q{
    SELECT COUNT(*)
    FROM letter
    WHERE module = 'circulation'
    AND code = 'DUE'
    AND message_transport_type = 'print'
});

unless ($letter_exists) {
    # Copy the email version to create print version
    $dbh->do(q{
        INSERT INTO letter (module, code, branchcode, name, is_html, title, content, message_transport_type, lang)
        SELECT module, code, branchcode, name, is_html, title, content, 'print', lang
        FROM letter
        WHERE module = 'circulation'
        AND code = 'DUE'
        AND message_transport_type = 'email'
        AND branchcode = ''
        LIMIT 1
    });
    print "✓ Created DUE letter template for print transport\n";
}

# Get current date for realistic due date
my $today = DateTime->now();
my $due_date = $today->clone->subtract(days => 1); # Make it overdue by 1 day

# Create a test message in the queue for print delivery
my $letter_content = "Dear " . $patron->firstname . " " . $patron->surname . ",\n\n";
$letter_content .= "This is a test due notice for testing print notice charges.\n\n";
$letter_content .= "The following item is overdue:\n";
$letter_content .= "Test Book Title by Test Author\n";
$letter_content .= "Barcode: TEST123456\n";
$letter_content .= "Due date: " . $due_date->ymd() . "\n\n";
$letter_content .= "Please return this item as soon as possible.\n\n";
$letter_content .= "Thank you,\nYour Library";

# Insert the test notice into message_queue
my $sth = $dbh->prepare(q{
    INSERT INTO message_queue (
        borrowernumber,
        subject,
        content,
        letter_code,
        message_transport_type,
        status,
        time_queued,
        to_address
    ) VALUES (?, ?, ?, ?, ?, ?, NOW(), ?)
});

$sth->execute(
    $borrowernumber,
    "Test Due Notice - Item Overdue",
    $letter_content,
    'DUE',
    'print',
    'pending',
    $patron->address || 'Test Address'
);

my $message_id = $dbh->last_insert_id(undef, undef, 'message_queue', 'message_id');

print "✓ Created test due notice in message queue (ID: $message_id)\n";
print "✓ Notice is configured for PRINT delivery\n";
print "✓ Status: pending (ready for gather_print_notices.pl processing)\n\n";

print "Next steps to test the FULL FLOW with messaging preferences:\n";
print "1. Create an overdue item for borrower $borrowernumber (check out an item and backdate it)\n";
print "2. Run: misc/cronjobs/advance_notices.pl -c\n";
print "   This will create a DUE notice with print transport based on messaging preferences\n";
print "3. Run: misc/cronjobs/gather_print_notices.pl\n";
print "   This will process the print notice and apply the charge\n";
print "4. Check patron account for print notice charges\n\n";

print "Alternative - Quick test with the direct message I created:\n";
print "1. Run: misc/cronjobs/gather_print_notices.pl\n";
print "2. Check results:\n";
print "   SELECT * FROM message_queue WHERE message_id = $message_id;\n";
print "   SELECT * FROM accountlines WHERE borrowernumber = $borrowernumber AND debit_type_code = 'PRINT_NOTICE';\n\n";

print "Test setup complete!\n";
print "✓ Borrower $borrowernumber now has print AND email messaging preferences for due notices\n";
print "✓ System is ready to test print notice charging\n\n";

print "===== TESTING SCENARIOS =====\n";
print "To test print charging vs email (no charge):\n\n";

print "SCENARIO 1 - Print notices (should be charged):\n";
print "1. Create overdue item for borrower $borrowernumber\n";
print "2. Run: misc/cronjobs/advance_notices.pl -c\n";
print "3. Check message_queue: SELECT * FROM message_queue WHERE borrowernumber = $borrowernumber AND message_transport_type = 'print';\n";
print "4. Run: misc/cronjobs/gather_print_notices.pl\n";
print "5. Check charges: SELECT * FROM accountlines WHERE borrowernumber = $borrowernumber AND debit_type_code = 'PRINT_NOTICE';\n\n";

print "SCENARIO 2 - Email notices (should NOT be charged):\n";
print "1. Run: perl toggle_messaging_preference.pl $borrowernumber email\n";
print "2. Create another overdue item for borrower $borrowernumber\n";
print "3. Run: misc/cronjobs/advance_notices.pl -c\n";
print "4. Check message_queue: SELECT * FROM message_queue WHERE borrowernumber = $borrowernumber AND message_transport_type = 'email';\n";
print "5. Run: misc/cronjobs/gather_print_notices.pl (should not process email notices)\n";
print "6. Verify no new charges: SELECT * FROM accountlines WHERE borrowernumber = $borrowernumber AND debit_type_code = 'PRINT_NOTICE';\n\n";

print "✓ Toggle script 'toggle_messaging_preference.pl' is ready for testing both scenarios\n\n";

print "COMPLETE TEST FLOW:\n";
print "==================\n";
print "1. Run setup_test_due_notice.pl (done!)\n";
print "2. Test print charging: perl toggle_messaging_preference.pl $borrowernumber print\n";
print "3. Test email (no charge): perl toggle_messaging_preference.pl $borrowernumber email\n\n";

print "This perfectly mimics the UI messaging preferences functionality!\n";