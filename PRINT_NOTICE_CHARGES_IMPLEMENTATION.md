# Print Notice Charges Implementation Tracker

## Project Overview
Implementation of optional charging for print notices in Koha, allowing libraries to recover costs for postage and staff time.

**Target Branch:** `charge-print-notices` (current branch)
**Koha Version:** Based on codebase analysis, appears to be 24.x or later

## Architectural Context

### Key Components Identified
- **Messaging System:** Enhanced messaging preferences (`EnhancedMessagingPreferences` syspref)
- **Transport Types:** email, print, sms, phone, itiva (in `message_transport_types` table)
- **Print Processing:** `misc/cronjobs/gather_print_notices.pl` handles print notice generation
- **Billing System:** `accountlines` table + `Koha::Account` API for charges
- **Debit Types:** `account_debit_types` table defines charge categories

### Current Print Notice Flow
1. Notices generated and queued in `message_queue` table with `message_transport_type = 'print'`
2. `gather_print_notices.pl` cronjob processes pending print notices
3. Notices formatted via `koha-tmpl/intranet-tmpl/prog/en/modules/batch/print-notices.tt`
4. Message status updated to 'sent' in `message_queue`

**Our Goal:** Insert charging logic at step 4 before status update.

## Phase 1: Database Schema & System Preferences

### System Preferences
**Files:** `installer/data/mysql/updatedatabase.pl`, `koha-tmpl/intranet-tmpl/prog/en/modules/admin/preferences/patrons.pref`

- [ ] **Add `PrintNoticeCharging` system preference (YesNo)**
  ```sql
  INSERT INTO systempreferences (variable, value, explanation, type)
  VALUES ('PrintNoticeCharging', '0', 'Enable charging for print notices', 'YesNo');
  ```
  **Location:** Add to `installer/data/mysql/mandatory/sysprefs.sql`
  **Expected Result:** Preference appears in Admin > System Preferences > Patrons

- [ ] **Add `PrintNoticeChargeAmount` system preference (Float)**
  ```sql
  INSERT INTO systempreferences (variable, value, explanation, type, options)
  VALUES ('PrintNoticeChargeAmount', '0.50', 'Amount to charge for each print notice', 'Float', NULL);
  ```
  **Location:** Same file as above
  **Expected Result:** Numeric input field in system preferences

- [ ] **Create database updater script for new preferences**
  ```perl
  $DBversion = 'XXX.XXX.XXX.XXX';
  if ( CheckVersion($DBversion) ) {
      $dbh->do(q{
          INSERT IGNORE INTO systempreferences (variable, value, explanation, type)
          VALUES ('PrintNoticeCharging', '0', 'Enable charging for print notices', 'YesNo')
      });
      $dbh->do(q{
          INSERT IGNORE INTO systempreferences (variable, value, explanation, type)
          VALUES ('PrintNoticeChargeAmount', '0.50', 'Amount to charge for each print notice', 'Float')
      });

      SetVersion($DBversion);
      print "Upgrade to $DBversion done (Bug XXXXX: Add print notice charging preferences)\n";
  }
  ```
  **Location:** `new atomic update file` same directory as skeleton.pl but use other atomic updates as reference

- [ ] **Add preferences to admin interface configuration**
  **File:** `koha-tmpl/intranet-tmpl/prog/en/modules/admin/preferences/patrons.pref`
  **Insert after line ~176 (in "Notices and notifications" section):**
  ```yaml
      -
          - pref: PrintNoticeCharging
            choices:
                1: Enable
                0: Disable
          - charging for print notices.
          - "<br><strong>NOTE:</strong> When enabled, patrons will be charged for each print notice sent."
      -
          - Charge
          - pref: PrintNoticeChargeAmount
            class: currency
          - for each print notice sent to patrons.
  ```

- [ ] **Commit:** `Add system preferences for print notice charging`

### Database Schema Updates

- [ ] **Create new debit type `PRINT_NOTICE` in account_debit_types**
  ```sql
  INSERT INTO account_debit_types (code, description, can_be_invoiced, can_be_sold, default_amount, is_system, restricts_checkouts)
  VALUES ('PRINT_NOTICE', 'Print notice charge', 0, 0, 0.50, 1, 0);
  ```
  **Context:** System debit types (is_system=1) cannot be deleted by users
  **Location:** We can modify the table in kohastructure.pl

- [ ] **Update database updater script for debit type**
  **Add to same version block in same atomic update:**
  ```perl
  $dbh->do(q{
      INSERT IGNORE INTO account_debit_types (code, description, can_be_invoiced, can_be_sold, default_amount, is_system, restricts_checkouts)
      VALUES ('PRINT_NOTICE', 'Print notice charge', 0, 0, 0.50, 1, 0)
  });
  ```

- [ ] **Commit:** `Add PRINT_NOTICE debit type for print notice charges`

## Phase 2: Backend Logic Implementation

### Account/Billing System
**Primary Files:** `Koha/Account.pm`, `misc/cronjobs/gather_print_notices.pl`

- [ ] **Create function to apply print notice charges in Account.pm**
  **File:** `Koha/Account.pm`
  **Insert after line ~816 (after existing methods):**
  ```perl
  =head3 add_print_notice_charge

    $account->add_print_notice_charge({
        notice_code => $letter_code,
        library_id  => $branchcode,
        amount      => $charge_amount  # optional, uses syspref if not provided
    });

  Adds a print notice charge to the patron's account if charging is enabled.

  =cut

  sub add_print_notice_charge {
      my ( $self, $params ) = @_;

      # Check if charging is enabled
      return unless C4::Context->preference('PrintNoticeCharging');

      my $charge_amount = $params->{amount} || C4::Context->preference('PrintNoticeChargeAmount');
      return unless $charge_amount && $charge_amount > 0;

      my $description = "Print notice";
      $description .= ": " . $params->{notice_code} if $params->{notice_code};

      return $self->add_debit({
          amount      => $charge_amount,
          description => $description,
          type        => 'PRINT_NOTICE',
          interface   => 'cron',
          library_id  => $params->{library_id} || C4::Context->userenv->{branch},
      });
  }
  ```

- [ ] **Add charge application logic to gather_print_notices.pl**
  **File:** `misc/cronjobs/gather_print_notices.pl`
  **Current logic at lines 195-205:** Messages marked as 'sent' without charging
  **Insert before the _set_message_status call (around line 202):**
  ```perl
  # Apply print notice charges if enabled
  if (C4::Context->preference('PrintNoticeCharging')) {
      apply_print_notice_charge($message);
  }
  ```

- [ ] **Add helper functions for checking if charging is enabled**
  **File:** `misc/cronjobs/gather_print_notices.pl`
  **Insert after line 444 (end of file, before POD):**
  ```perl
  =head2 apply_print_notice_charge

  Apply a print notice charge to the patron's account

  =cut

  sub apply_print_notice_charge {
      my ($message) = @_;

      return unless $message->{borrowernumber};

      my $patron = Koha::Patrons->find($message->{borrowernumber});
      return unless $patron;

      eval {
          my $account = Koha::Account->new({ patron_id => $patron->borrowernumber });
          $account->add_print_notice_charge({
              notice_code => $message->{letter_code},
              library_id  => $message->{branchcode},
          });
      };

      if ($@) {
          warn "Error applying print notice charge for patron " . $patron->borrowernumber . ": $@";
      }
  }
  ```

- [ ] **Add validation for charge amounts**
  **File:** `Koha/Account.pm` (in the add_print_notice_charge method)
  **Add validation logic:**
  ```perl
  # Validate charge amount
  if ($charge_amount !~ /^\d+\.?\d*$/ || $charge_amount < 0) {
      carp "Invalid print notice charge amount: $charge_amount";
      return;
  }
  ```

- [ ] **Commit:** `Implement print notice charging backend logic`

### Print Notice Processing

- [ ] **Update gather_print_notices.pl to handle charging**
  **Current structure:** Lines 140-210 contain the print_notices function
  **Add use statements at top of file (after line 16):**
  ```perl
  use Koha::Account;
  use Koha::Patrons;
  ```

- [ ] **Add configuration options for charging behavior**
  **File:** `misc/cronjobs/gather_print_notices.pl`
  **Add new command line option after line 45:**
  ```perl
  my $skip_charges;

  # In GetOptions section (around line 38):
  'skip-charges'  => \$skip_charges,

  # In POD documentation:
  =item B<--skip-charges>

  Skip applying charges for print notices, even if PrintNoticeCharging is enabled.
  Useful for testing or administrative runs.
  ```

- [ ] **Add logging for charge applications**
  **File:** `misc/cronjobs/gather_print_notices.pl`
  **In apply_print_notice_charge function:**
  ```perl
  if ($message->{borrowernumber}) {
      cronlogaction({
          action => 'Print notice charge',
          info   => "Applied charge for patron " . $message->{borrowernumber} .
                   " notice " . ($message->{letter_code} || 'unknown')
      });
  }
  ```

- [ ] **Handle edge cases (missing patron data, etc.)**
  **File:** `misc/cronjobs/gather_print_notices.pl`
  **Enhanced error handling in apply_print_notice_charge:**
  ```perl
  # Check for valid message data
  unless ($message && ref($message) eq 'HASH') {
      warn "Invalid message data passed to apply_print_notice_charge";
      return;
  }

  # Check for borrowernumber
  unless ($message->{borrowernumber}) {
      warn "No borrowernumber in message for print notice charge";
      return;
  }

  # Skip if patron not found
  my $patron = Koha::Patrons->find($message->{borrowernumber});
  unless ($patron) {
      warn "Patron " . $message->{borrowernumber} . " not found for print notice charge";
      return;
  }
  ```

- [ ] **Commit:** `Update print notice processing to apply charges`

## Phase 3: Staff Interface Updates

### Messaging Preferences (Staff)
**Primary Files:**
- `koha-tmpl/intranet-tmpl/prog/en/includes/messaging-preference-form.inc`
- `members/memberentry.pl`
- `koha-tmpl/intranet-tmpl/prog/en/modules/members/memberentrygen.tt`

- [ ] **Update messaging-preference-form.inc template**
  **File:** `koha-tmpl/intranet-tmpl/prog/en/includes/messaging-preference-form.inc`
  **Current print column header at line ~15:** `<th>Email</th>`
  **Find print-related headers and update around line 12:**
  ```html
  [% IF Koha.Preference('PrintNoticeCharging') %]
      <th>Print
          [% IF Koha.Preference('PrintNoticeChargeAmount') > 0 %]
              ([% Koha.Preference('PrintNoticeChargeAmount') | $Price %] charge)
          [% END %]
      </th>
  [% ELSE %]
      <th>Print</th>
  [% END %]
  ```

- [ ] **Add charge amount display in print column headers**
  **Context:** The messaging-preference-form.inc is included in multiple places
  **Test locations:**
  - Member entry form (`members/memberentry.pl`)
  - Patron category configuration (`admin/categories.pl`)

- [ ] **Add warning messages for patrons without email**
  **File:** `koha-tmpl/intranet-tmpl/prog/en/modules/members/memberentrygen.tt`
  **Insert after line 1606 (in messaging preferences section):**
  ```html
  [% IF Koha.Preference('PrintNoticeCharging') && !borrower.email %]
      <div class="alert alert-warning">
          <i class="fa fa-exclamation-triangle"></i>
          <strong>Notice:</strong> This patron has no email address.
          Print notices will incur a charge of [% Koha.Preference('PrintNoticeChargeAmount') | $Price %] each.
          Consider encouraging the patron to provide an email address to avoid these charges.
      </div>
  [% END %]
  ```

- [ ] **Update memberentry.pl controller logic**
  **File:** `members/memberentry.pl`
  **Add around line 852 (in template parameter section):**
  ```perl
  if (C4::Context->preference('PrintNoticeCharging')) {
      $template->param(
          print_notice_charging => 1,
          print_notice_charge_amount => C4::Context->preference('PrintNoticeChargeAmount'),
      );
  }
  ```

- [ ] **Update members/notices.pl for charge display**
  **File:** `members/notices.pl`
  **Current template parameters around line 145:**
  **Add print charge context:**
  ```perl
  $template->param(
      patron          => $patron,
      QUEUED_MESSAGES => $queued_messages,
      borrowernumber  => $borrowernumber,
      sentnotices     => 1,
      print_notice_charging => C4::Context->preference('PrintNoticeCharging'),
  );
  ```

- [ ] **Commit:** `Update staff messaging preferences interface`

### Account Management
**Files:** Template includes and account display pages

- [ ] **Update accounts.inc template for PRINT_NOTICE description**
  **File:** `koha-tmpl/intranet-tmpl/prog/en/includes/accounts.inc`
  **Current debit type descriptions start around line 10**
  **Add after line 38 (after RESERVE_EXPIRED case):**
  ```html
  [%~ CASE 'PRINT_NOTICE' ~%]
      <span>Print notice charge</span>
  ```

  **Also update OPAC version:**
  **File:** `koha-tmpl/opac-tmpl/bootstrap/en/includes/accounts.inc`
  **Add similar case around line 38:**
  ```html
  [%- CASE 'PRINT_NOTICE' -%]
      <span>Print notice charge</span>
  ```

- [ ] **Add print notice charges to account display**
  **Files affected:** All account display templates already use the accounts.inc include
  **Expected result:** Print notice charges will automatically display with proper description

- [ ] **Update account line details display**
  **File:** `koha-tmpl/intranet-tmpl/prog/en/modules/members/accountline-details.tt`
  **No changes needed - uses existing account line display logic**

- [ ] **Commit:** `Add print notice charges to account management`

### Patron Tools & Reports

- [ ] **Add indicators for patrons with print preferences enabled**
  **File:** `koha-tmpl/intranet-tmpl/prog/en/includes/members-toolbar.inc`
  **Current print section starts around line 38**
  **Add warning indicator if print charging enabled:**
  ```html
  [% IF CAN_user_circulate_circulate_remaining_permissions %]
      <div class="btn-group">
          <button class="btn btn-default dropdown-toggle" data-bs-toggle="dropdown" aria-expanded="false">
              <i class="fa fa-print"></i> Print
              [% IF Koha.Preference('PrintNoticeCharging') && patron.has_print_notices %]
                  <i class="fa fa-exclamation-triangle text-warning" title="Print notices will incur charges"></i>
              [% END %]
          </button>
  ```

- [ ] **Update patron toolbar for print charge indicators**
  **Context:** Need to determine if patron has print messaging preferences enabled
  **May require controller logic to check messaging preferences**

- [ ] **Add print charge information to patron summary**
  **File:** `koha-tmpl/intranet-tmpl/prog/en/modules/members/moremember.tt`
  **Add to patron information section around line 200:**
  ```html
  [% IF Koha.Preference('PrintNoticeCharging') %]
      <li><span class="label">Print notice charges:</span>
          [% IF patron.print_notices_enabled %]
              <span class="text-warning">Enabled ([% Koha.Preference('PrintNoticeChargeAmount') | $Price %] per notice)</span>
          [% ELSE %]
              <span class="text-success">No print notices configured</span>
          [% END %]
      </li>
  [% END %]
  ```

- [ ] **Commit:** `Add patron tools for print notice charge management`

## Phase 4: OPAC Interface Updates

### Messaging Preferences (OPAC)
**Primary Files:** `opac/opac-messaging.pl`, `koha-tmpl/opac-tmpl/bootstrap/en/modules/opac-messaging.tt`

- [ ] **Update opac-messaging.pl controller**
  **File:** `opac/opac-messaging.pl`
  **Current template parameters around line 131**
  **Add after existing parameters:**
  ```perl
  if (C4::Context->preference('PrintNoticeCharging')) {
      $template->param(
          print_notice_charging => 1,
          print_notice_charge_amount => C4::Context->preference('PrintNoticeChargeAmount'),
          patron_has_email => $patron->notice_email_address,
      );
  }
  ```

- [ ] **Update opac-messaging.tt template**
  **File:** `koha-tmpl/opac-tmpl/bootstrap/en/modules/opac-messaging.tt`
  **Current messaging preferences table starts around line 42**
  **Add warning section before table (around line 40):**
  ```html
  [% IF Koha.Preference('PrintNoticeCharging') && !patron_has_email %]
      <div class="alert alert-warning">
          <h4><i class="fa fa-exclamation-triangle"></i> Print Notice Charges</h4>
          <p><strong>Important:</strong> Print notices incur a charge of
             [% print_notice_charge_amount | $Price %] each.</p>
          <p>To avoid these charges, please provide an email address in your account
             and select email delivery for your notices.</p>
      </div>
  [% END %]
  ```

- [ ] **Add charge warnings for users without email**
  **Same file, modify print column logic around line 180:**
  ```html
  [% IF messaging_preference.transport_print %]
      <td class="selectcol">
          [% IF Koha.Preference('PrintNoticeCharging') %]
              <div class="print-notice-warning">
                  <small class="text-warning">
                      <i class="fa fa-exclamation-triangle"></i>
                      [% print_notice_charge_amount | $Price %] charge per notice
                  </small>
              </div>
          [% END %]
          <!-- existing checkbox code continues -->
      </td>
  [% END %]
  ```

- [ ] **Add clear messaging about avoiding charges**
  **Add help section after messaging preferences table:**
  ```html
  [% IF Koha.Preference('PrintNoticeCharging') %]
      <div class="alert alert-info">
          <h5>About Print Notice Charges</h5>
          <p>Print notices incur a charge of [% print_notice_charge_amount | $Price %]
             to cover postage and processing costs.</p>
          <p><strong>To avoid charges:</strong></p>
          <ul>
              <li>Provide an email address in your account</li>
              <li>Select "Email" instead of "Print" for your notice preferences</li>
              <li>Uncheck "Print" options for notice types you don't need</li>
          </ul>
      </div>
  [% END %]
  ```

- [ ] **Restrict print options based on email availability**
  **Context:** This is a UX decision - may want to hide print options when email is available**
  **Implementation in opac-messaging.tt:**
  ```html
  [% IF messaging_preference.transport_print %]
      [% IF !Koha.Preference('PrintNoticeCharging') || !patron_has_email %]
          <!-- Show print option normally -->
      [% ELSE %]
          <!-- Show print option with strong warning or hide it -->
          <td class="selectcol">
              <small class="text-muted">
                  Print option available but email is recommended to avoid charges
              </small>
          </td>
      [% END %]
  [% END %]
  ```

- [ ] **Commit:** `Update OPAC messaging preferences for print charges`

### User Experience Enhancements

- [ ] **Add dashboard warnings about potential charges**
  **File:** `koha-tmpl/opac-tmpl/bootstrap/en/modules/opac-main.tt`
  **Add to patron information section if logged in:**
  ```html
  [% IF logged_in_user && Koha.Preference('PrintNoticeCharging') %]
      [% IF patron.has_print_notices_without_email %]
          <div class="alert alert-warning">
              <strong>Notice:</strong> You have print notices enabled which incur charges.
              <a href="/cgi-bin/koha/opac-messaging.pl">Update your preferences</a> to use email instead.
          </div>
      [% END %]
  [% END %]
  ```

- [ ] **Update account display in OPAC**
  **File:** `koha-tmpl/opac-tmpl/bootstrap/en/modules/opac-account.tt`
  **Uses accounts.inc which we've already updated**
  **No additional changes needed**

- [ ] **Add help text explaining print notice charges**
  **File:** `koha-tmpl/opac-tmpl/bootstrap/en/modules/opac-account.tt`
  **Add help section about print charges:**
  ```html
  [% IF Koha.Preference('PrintNoticeCharging') %]
      <div class="alert alert-info">
          <h5>About Print Notice Charges</h5>
          <p>Print notices are charged at [% Koha.Preference('PrintNoticeChargeAmount') | $Price %]
             each to cover postage and processing costs. You can avoid these charges by:</p>
          <ul>
              <li>Providing an email address in your account</li>
              <li>Selecting email delivery in your
                  <a href="/cgi-bin/koha/opac-messaging.pl">messaging preferences</a></li>
          </ul>
      </div>
  [% END %]
  ```

- [ ] **Commit:** `Enhance OPAC user experience for print notice charges`

## Phase 5: System Preferences Interface

### Admin Configuration

- [ ] **Add preferences to patrons.pref file**
  **File:** `koha-tmpl/intranet-tmpl/prog/en/modules/admin/preferences/patrons.pref`
  **Insert location:** After line 176 in "Notices and notifications" section
  **Code provided in Phase 1 above**

- [ ] **Create preferences section for print notices**
  **Consider creating new section in patrons.pref:**
  ```yaml
  Print notices:
      -
          - pref: PrintNoticeCharging
            choices:
                1: Enable
                0: Disable
          - charging for print notices to recover postage and processing costs.
          - "<br><strong>NOTE:</strong> When enabled, patrons will be charged for each print notice sent via gather_print_notices.pl."
      -
          - Charge
          - pref: PrintNoticeChargeAmount
            class: currency
          - for each print notice sent to patrons.
          - "<br><strong>NOTE:</strong> Amount should reflect actual costs for postage and staff time."
  ```

- [ ] **Add help text and explanations**
  **Enhanced explanations in preference descriptions:**
  - Link to documentation about print notice processing
  - Explain when charges are applied (during cronjob execution)
  - Mention impact on patron messaging preferences

- [ ] **Test preference saving and loading**
  **Test scenarios:**
  - Save preferences with various values
  - Verify preferences appear in patron messaging interface
  - Test with EnhancedMessagingPreferences disabled
  - Verify database updates work correctly

- [ ] **Commit:** `Add print notice charging system preferences to admin interface`

### Permission Management

- [ ] **Consider adding manage_print_notice_charges permission**
  **File:** `installer/data/mysql/updatedatabase.pl`
  **Add to same version block:**
  ```perl
  $dbh->do(q{
      INSERT IGNORE INTO permissions (module_bit, code, description)
      VALUES (3, 'manage_print_notice_charges', 'Manage print notice charging settings')
  });
  ```
  **Module_bit 3 = borrowers/patron management**

- [ ] **Update permission checks in relevant scripts**
  **Files to consider:**
  - `admin/preferences.pl` (check if print notice prefs need special permissions)
  - `misc/cronjobs/gather_print_notices.pl` (already runs as system)
  - Staff messaging preference pages

- [ ] **Add permission to installer data**
  **File:** `installer/data/mysql/userflags.sql`
  **Verify permission is properly categorized**

- [ ] **Commit:** `Add permissions for print notice charge management`

## Phase 6: Testing & Quality Assurance

### Unit Tests
**Test File Locations:** `t/db_dependent/` and `t/`

- [ ] **Write tests for print notice charging logic**
  **File:** `t/db_dependent/Koha/Account/PrintNoticeCharges.t`
  ```perl
  #!/usr/bin/perl

  use Modern::Perl;
  use Test::More tests => 20;
  use Test::MockModule;
  use t::lib::TestBuilder;
  use t::lib::Mocks;

  use C4::Context;
  use Koha::Account;
  use Koha::Patrons;

  my $schema = Koha::Database->new->schema;
  my $builder = t::lib::TestBuilder->new;

  subtest 'add_print_notice_charge with charging disabled' => sub {
      plan tests => 3;

      t::lib::Mocks::mock_preference('PrintNoticeCharging', 0);

      my $patron = $builder->build_object({ class => 'Koha::Patrons' });
      my $account = Koha::Account->new({ patron_id => $patron->borrowernumber });

      my $result = $account->add_print_notice_charge({
          notice_code => 'TEST',
          library_id => 'CPL'
      });

      is($result, undef, 'No charge applied when charging disabled');
      is($account->balance, 0, 'Account balance unchanged');
      is($account->lines->count, 0, 'No account lines created');
  };
  ```

- [ ] **Write tests for system preference handling**
  **File:** `t/db_dependent/sysprefs/PrintNoticeCharging.t`
  **Test preference validation, default values, and interaction with messaging system**

- [ ] **Write tests for debit type functionality**
  **File:** `t/db_dependent/Koha/Account/DebitTypes/PrintNotice.t`
  **Test PRINT_NOTICE debit type creation, system flag, and restrictions**

- [ ] **Write tests for messaging preference updates**
  **File:** `t/db_dependent/Members/Messaging/PrintCharges.t`
  **Test messaging preference display with charging enabled/disabled**

- [ ] **Commit:** `Add unit tests for print notice charging`

### Integration Tests

- [ ] **Test end-to-end print notice charging workflow**
  **File:** `t/db_dependent/PrintNoticeCharging_EndToEnd.t`
  **Test scenario:**
  1. Enable print notice charging
  2. Set up patron with print messaging preferences
  3. Generate notice that goes to print queue
  4. Run gather_print_notices.pl (mock)
  5. Verify charge applied to patron account

- [ ] **Test messaging preference interactions**
  **Test combinations:**
  - Patron with email + print preferences
  - Patron without email + print preferences
  - Charging enabled/disabled states
  - Various charge amounts including 0

- [ ] **Test account line creation and display**
  **Verify:**
  - PRINT_NOTICE debit type displays correctly
  - Account lines have proper descriptions
  - Charges appear in patron account views
  - Reports include print notice charges

- [ ] **Test OPAC and staff interface integration**
  **Manual testing scenarios:**
  - Staff member views patron with print charges
  - Patron logs into OPAC and sees print charge warnings
  - Messaging preference changes in staff interface
  - Messaging preference changes in OPAC

- [ ] **Commit:** `Add integration tests for print notice charging`

### Edge Case Testing

- [ ] **Test with patrons without borrowernumber**
  **Scenario:** Corrupted message queue data**
  **Expected:** Graceful failure, no charges applied, warning logged**

- [ ] **Test with invalid charge amounts**
  **Test cases:**
  - Negative amounts
  - Non-numeric amounts
  - Zero amounts
  - Very large amounts

- [ ] **Test with disabled charging preference**
  **Verify no charges applied when PrintNoticeCharging = 0**

- [ ] **Test backwards compatibility**
  **Scenarios:**
  - Existing installations upgrading
  - Sites with custom debit types
  - Sites with modified messaging preferences

- [ ] **Commit:** `Add edge case testing and fixes`

## Phase 7: Documentation & Localization

### Documentation Updates

- [ ] **Update release notes**
  **File:** `misc/release_notes/release_notes_XX_XX_XX.md`
  **Add feature description, configuration instructions, upgrade notes**

- [ ] **Create administrator documentation**
  **Topics to cover:**
  - How to enable print notice charging
  - Setting charge amounts
  - Understanding the billing process
  - Troubleshooting common issues
  - Impact on existing workflows

- [ ] **Update user guides for OPAC changes**
  **Document:**
  - New warning messages
  - How to avoid print charges
  - Messaging preference changes

- [ ] **Document new system preferences**
  **Include in system preference documentation:**
  - Purpose and function
  - Interaction with other preferences
  - Recommended settings

- [ ] **Commit:** `Add documentation for print notice charging feature`

### Localization

- [ ] **Add translation strings for new interface text**
  **Files:** All `.tt` template files modified
  **Ensure all user-visible text is translatable:**
  ```html
  <!-- Instead of: -->
  <span>Print notice charge</span>

  <!-- Use: -->
  <span>[% t("Print notice charge") %]</span>
  ```

- [ ] **Update template files for translation support**
  **Review all modified templates for hardcoded English text**

- [ ] **Test with multiple languages**
  **Install language packs and verify:**
  - Preference descriptions translate
  - Interface warnings translate
  - Account line descriptions translate

- [ ] **Commit:** `Add localization support for print notice charging`

## Phase 8: Performance & Security

### Performance Optimization

- [ ] **Optimize database queries for charging logic**
  **Review query performance:**
  - `C4::Context->preference()` calls (cached)
  - Patron lookups in gather_print_notices.pl
  - Account line creation queries

- [ ] **Review gather_print_notices.pl performance impact**
  **Considerations:**
  - Additional database writes for each charged notice
  - Error handling for failed charges
  - Impact on large print notice runs

- [ ] **Add database indexes if needed**
  **Review indexing on:**
  - `accountlines.debit_type_code`
  - `message_queue.borrowernumber`
  - New query patterns

- [ ] **Commit:** `Optimize performance for print notice charging`

### Security Review

- [ ] **Review permission requirements**
  **Verify:**
  - System preferences properly protected
  - Cronjob security (runs as koha user)
  - No privilege escalation paths

- [ ] **Validate input sanitization**
  **Check:**
  - Charge amount validation
  - SQL injection prevention
  - XSS prevention in templates

- [ ] **Check for potential security vulnerabilities**
  **Areas to review:**
  - File permissions on gather_print_notices.pl
  - Template security
  - Database transaction safety

- [ ] **Commit:** `Security review and fixes for print notice charging`

## Phase 9: Final Integration & Polish

### Code Review & Cleanup

- [ ] **Code review of all changes**
  **Review checklist:**
  - Code follows Koha coding standards
  - POD documentation complete
  - Error handling comprehensive
  - No debugging code left in

- [ ] **Cleanup debug code and comments**
  **Remove:**
  - Debug print statements
  - Temporary comments
  - Unused variables
  - Test-only code

- [ ] **Ensure consistent coding style**
  **Verify:**
  - Indentation consistent (4 spaces)
  - Variable naming conventions
  - Subroutine organization
  - Template formatting

- [ ] **Update POD documentation**
  **Ensure all new subroutines have proper POD:**
  ```perl
  =head3 method_name

    my $result = $object->method_name({ param => $value });

  Description of what the method does.

  Parameters:
  - param: Description of parameter

  Returns: Description of return value

  =cut
  ```

- [ ] **Commit:** `Code cleanup and final review for print notice charging`

### Feature Integration

- [ ] **Test with various Koha configurations**
  **Test scenarios:**
  - Single-branch vs multi-branch
  - Different messaging preference setups
  - Various patron categories
  - Different notice types

- [ ] **Verify backwards compatibility**
  **Ensure:**
  - Existing notices still work
  - Existing preferences unchanged
  - No database schema conflicts
  - Existing cronjobs unaffected

- [ ] **Test upgrade scenarios**
  **Test database upgrades:**
  - Fresh installation
  - Upgrade from previous version
  - Multiple upgrade paths
  - Rollback scenarios

- [ ] **Final user acceptance testing**
  **End-to-end testing:**
  - Library staff workflow
  - Patron experience
  - Administrative setup
  - Troubleshooting scenarios

- [ ] **Commit:** `Final integration and testing for print notice charging`

## Deployment Checklist

### Pre-Deployment
- [ ] All tests passing
- [ ] Documentation complete
- [ ] Database updaters tested
- [ ] Backup procedures documented
- [ ] Training materials prepared

### Post-Deployment
- [ ] Monitor for issues
- [ ] Gather user feedback
- [ ] Performance monitoring
- [ ] Support documentation updated

## Notes & Decisions

### Configuration Decisions
- **Default charge amount:** $0.50 (configurable)
- **Charging disabled by default** for backwards compatibility
- **Print option behavior:** Show with warnings when charging enabled

### Technical Decisions
- **Storage:** Use existing `accountlines` table for charges
- **Identification:** New `PRINT_NOTICE` debit type for clear identification
- **Timing:** Charges applied during `gather_print_notices.pl` execution
- **Configuration:** System preferences for global configuration
- **Architecture:** Extend existing Account/billing API

### User Experience Decisions
- **Transparency:** Clear warnings before charges are incurred
- **Avoidance:** Easy path to avoid charges (provide email)
- **Visibility:** Staff tools to identify affected patrons
- **Control:** Granular control over print preferences

### Database Schema Decisions
- **Debit Type:** `PRINT_NOTICE` as system debit type (cannot be deleted)
- **Permissions:** Use existing borrowers permission set
- **Preferences:** Two separate preferences for enable/amount
- **Backwards Compatibility:** All changes optional and backwards-compatible

---

## Git Workflow

Each major phase should be committed separately with descriptive commit messages:

```bash
git add .
git commit -m "Phase X: Brief description

- Specific change 1
- Specific change 2
- Specific change 3

Addresses print notice charging implementation
Bug XXXXX: Add print notice charging feature"
```

## Branch Strategy

Current branch: `charge-print-notices`

Consider feature branches for major phases:
- `feature/print-notice-charging-backend`
- `feature/print-notice-charging-ui`
- `feature/print-notice-charging-tests`

## Development Environment Notes

**Koha Installation:** `/Users/jacobdev/git/koha`
**Current Branch:** `charge-print-notices`
**Database:** Appears to be development setup
**Testing:** Use `prove` for running tests
**Templates:** Restart web server after template changes