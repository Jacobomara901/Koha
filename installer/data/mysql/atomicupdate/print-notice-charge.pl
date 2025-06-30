use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "XXXXX",
    description => "Add system preferences for print notice charging",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        # Add PrintNoticeCharging system preference
        $dbh->do(
            q{
            INSERT IGNORE INTO systempreferences (variable, value, explanation, type)
            VALUES ('PrintNoticeCharging', '0', 'Enable charging for print notices to recover postage and processing costs', 'YesNo')
        }
        );

        # Add PrintNoticeChargeAmount system preference
        $dbh->do(
            q{
            INSERT IGNORE INTO systempreferences (variable, value, explanation, type)
            VALUES ('PrintNoticeChargeAmount', '0.50', 'Amount to charge for each print notice sent to patrons', 'Float')
        }
        );

        # Add PRINT_NOTICE debit type
        $dbh->do(
            q{
            INSERT IGNORE INTO account_debit_types (code, description, can_be_invoiced, can_be_sold, default_amount, is_system, restricts_checkouts)
            VALUES ('PRINT_NOTICE', 'Print notice charge', 0, 0, 0.50, 1, 0)
        }
        );

        say_success( $out, "Added system preferences and debit type for print notice charging" );
    },
};