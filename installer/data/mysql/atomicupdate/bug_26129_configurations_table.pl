use Modern::Perl;

return {
    bug_number  => "26129",
    description => "Add a new 'configurations' table",
    up          => sub {
        my ($args) = @_;
        my ($dbh)  = @$args{qw(dbh out)};

        unless ( TableExists('configurations') ) {
            $dbh->do(
                q{
                CREATE TABLE `configurations` (
                    `id` INT(11) NOT NULL AUTO_INCREMENT COMMENT 'Unique ID of the configuration entry',
                    `library_id` VARCHAR(10) NULL DEFAULT NULL COMMENT 'Internal identifier for the library the config applies to. NULL means global',
                    `category_id` VARCHAR(10) NULL DEFAULT NULL COMMENT 'Internal identifier for the category the config applies to. NULL means global',
                    `item_type` VARCHAR(10) NULL DEFAULT NULL COMMENT 'Internal identifier for the item type the config applies to. NULL means global',
                    `name` VARCHAR(32) NOT NULL COMMENT 'Configuration entry name',
                    `value` MEDIUMTEXT NULL DEFAULT NULL COMMENT 'Configuration entry value',
                    `type` ENUM('text', 'boolean', 'integer') NOT NULL DEFAULT 'text' COMMENT 'Configuration entry type',
                    PRIMARY KEY (`id`),
                    KEY `library_id_idx` (`library_id`),
                    KEY `category_id_idx` (`category_id`),
                    KEY `item_type_idx` (`item_type`),
                    KEY `name_idx` (`name`),
                    KEY `type_idx` (`type`),
                    UNIQUE (`library_id`, `category_id`, `item_type`, `name`),
                    CONSTRAINT `library_id_fk` FOREIGN KEY (`library_id`) REFERENCES `branches` (`branchcode`) ON DELETE CASCADE ON UPDATE CASCADE,
                    CONSTRAINT `category_id_fk` FOREIGN KEY (`category_id`) REFERENCES `categories` (`categorycode`) ON DELETE CASCADE ON UPDATE CASCADE,
                    CONSTRAINT `item_type_fk` FOREIGN KEY (`item_type`) REFERENCES `itemtypes` (`itemtype`) ON DELETE CASCADE ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            }
            );
        }
    },
};
