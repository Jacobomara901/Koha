use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "34069",
    description => "Add new permission restore_deleted_borrowers",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        $dbh->do(
            q{INSERT IGNORE permissions (module_bit, code, description) VALUES (13, 'restore_deleted_borrowers', 'Restore deleted patrons')}
        );
        say_success( $out, "Added new permission 'restore_deleted_borrowers'" );

        $dbh->do(
            q{INSERT IGNORE INTO systempreferences (variable, value) VALUES ('AllowDeletedPatronRestoration', '0')});

        say_success( $out, "Added new system preference 'AllowDeletedPatronRestoration'" );
    },
};
