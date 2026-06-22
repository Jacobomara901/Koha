use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "XXXXX",
    description =>
        "Store OpacBrowseResults paging data ('busc') in its own table to avoid CGI::Session lost-update races",
    up => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        if ( !TableExists('opac_browse_results') ) {
            $dbh->do(
                q{
                CREATE TABLE `opac_browse_results` (
                  `session_id` varchar(32) NOT NULL COMMENT 'CGISESSID of the session this browse-results set belongs to',
                  `busc` longtext DEFAULT NULL COMMENT 'Encoded OpacBrowseResults paging data (search criteria and result biblionumbers)',
                  `updated_on` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'Date and time this row was last written, used for cleanup',
                  PRIMARY KEY (`session_id`),
                  KEY `opac_browse_results_updated_idx` (`updated_on`)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
                }
            );

            say_success( $out, "Added new table 'opac_browse_results'" );
        } else {
            say_info( $out, "Table 'opac_browse_results' already exists - skipping" );
        }
    },
};
