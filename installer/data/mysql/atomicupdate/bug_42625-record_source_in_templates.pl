use Modern::Perl;

return {
    bug_number  => "42625",
    description => "Add a record source to MARC modification templates",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        unless ( column_exists( 'marc_modification_templates', 'record_source_id' ) ) {
            $dbh->do(
                q{
                ALTER TABLE marc_modification_templates
                    ADD COLUMN `record_source_id` int(11) DEFAULT NULL COMMENT 'record source to set on bibliographic records modified with this template'
                    AFTER name,
                    ADD KEY `marc_modification_templates_ibfk_1` (`record_source_id`),
                    ADD CONSTRAINT `marc_modification_templates_ibfk_1` FOREIGN KEY (`record_source_id`) REFERENCES `record_sources` (`record_source_id`) ON DELETE SET NULL ON UPDATE CASCADE
                    }
            );

            say $out "Added column 'marc_modification_templates.record_source_id'";
        }

        unless ( column_exists( 'import_batches', 'record_source_id' ) ) {
            $dbh->do(
                q{
                ALTER TABLE import_batches
                    ADD COLUMN `record_source_id` int(11) DEFAULT NULL COMMENT 'record source to set on bibliographic records committed from this batch'
                    AFTER profile_id,
                    ADD KEY `import_batches_ibfk_2` (`record_source_id`),
                    ADD CONSTRAINT `import_batches_ibfk_2` FOREIGN KEY (`record_source_id`) REFERENCES `record_sources` (`record_source_id`) ON DELETE SET NULL ON UPDATE CASCADE
                    }
            );

            say $out "Added column 'import_batches.record_source_id'";
        }
    },
};
