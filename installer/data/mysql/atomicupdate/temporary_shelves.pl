use Modern::Perl;

return {
    bug_number  => "",
    description => "Add display tables for display module",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        # Create displays table
        unless ( TableExists('displays') ) {
            $dbh->do(
                q{
                CREATE TABLE IF NOT EXISTS `displays` (
                    `display_id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'unique id for the display',
                    `display_name` varchar(255) DEFAULT NULL COMMENT 'the name of the display',
                    `start_date` date DEFAULT NULL COMMENT 'the start date of the display (optional)',
                    `end_date` date DEFAULT NULL COMMENT 'the end date of the display (optional)',
                    `display_days` int(11) DEFAULT NULL COMMENT 'the number of days an item should stay in the display (optional)',
                    `enabled` tinyint(1) NOT NULL DEFAULT 1 COMMENT 'determines whether the display is active',
                    `display_location` varchar(80) DEFAULT NULL COMMENT 'the shelving location for the display (optional)',
                    `display_code` varchar(80) DEFAULT NULL COMMENT 'the collection code for the display (optional)',
                    `display_branch` varchar(10) DEFAULT NULL COMMENT 'a new home branch for the item to have while on display (optional)',
                    `display_type` varchar(10) DEFAULT NULL COMMENT 'a new itype for the item to have while on display (optional)',
                    `display_return_over` enum('yes','any library','not home library','no') NOT NULL DEFAULT 'no' COMMENT 'should the item be removed from the display when it is returned',
                    PRIMARY KEY (`display_id`),
                    KEY `display_branch` (`display_branch`),
                    KEY `display_type` (`display_type`),
                    CONSTRAINT `displays_ibfk_1` FOREIGN KEY (`display_branch`) REFERENCES `branches` (`branchcode`) ON DELETE CASCADE ON UPDATE CASCADE,
                    CONSTRAINT `displays_ibfk_2` FOREIGN KEY (`display_type`) REFERENCES `itemtypes` (`itemtype`) ON DELETE CASCADE ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            }
            );

            say $out "Added new table 'displays'";
        }

        # Create display_items table
        unless ( TableExists('display_items') ) {
            $dbh->do(
                q{
                CREATE TABLE IF NOT EXISTS `display_items` (
                    `display_item_id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'primary key',
                    `display_id` int(11) NOT NULL COMMENT 'foreign key to link to displays.display_id',
                    `itemnumber` int(11) DEFAULT NULL COMMENT 'items.itemnumber for the item on display',
                    `biblionumber` int(11) DEFAULT NULL COMMENT 'biblio.biblionumber for the bibliographic record on display',
                    `date_added` date DEFAULT NULL COMMENT 'the date the item was added to the display',
                    `date_remove` date DEFAULT NULL COMMENT 'the date the item should be removed from the display',
                    PRIMARY KEY (`display_item_id`),
                    UNIQUE KEY `display_items_uniq` (`display_id`,`itemnumber`),
                    KEY `display_id` (`display_id`),
                    KEY `itemnumber` (`itemnumber`),
                    KEY `biblionumber` (`biblionumber`),
                    CONSTRAINT `display_items_ibfk_1` FOREIGN KEY (`display_id`) REFERENCES `displays` (`display_id`) ON DELETE CASCADE ON UPDATE CASCADE,
                    CONSTRAINT `display_items_ibfk_2` FOREIGN KEY (`itemnumber`) REFERENCES `items` (`itemnumber`) ON DELETE CASCADE ON UPDATE CASCADE,
                    CONSTRAINT `display_items_ibfk_3` FOREIGN KEY (`biblionumber`) REFERENCES `biblio` (`biblionumber`) ON DELETE CASCADE ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            }
            );

            say $out "Added new table 'display_items'";
        }
    },
};
