use Modern::Perl;

return {
    bug_number  => "26129",
    description => "Add a new 'configurations' table with configuration groups",
    up          => sub {
        my ($args) = @_;
        my ($dbh)  = @$args{qw(dbh out)};

        unless ( TableExists('configuration_groups') ) {
            $dbh->do(
                q{
                    CREATE TABLE `configuration_groups` (
                        `bit` int(11) NOT NULL DEFAULT 0 COMMENT 'Unique bit identifier',
                        `flag` varchar(32) NOT NULL COMMENT 'The name/flag of this configuration group',
                        `flagdesc` varchar(255) NOT NULL COMMENT 'Description of this configuration group',
                        PRIMARY KEY (`bit`),
                        UNIQUE KEY `flag` (`flag`)
                    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
                }
            );
        }

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
                        `configuration_group_bit` INT(11) NULL DEFAULT NULL COMMENT 'Configuration group this setting applies to. Used for getting/setting all settings grouped for a specific configuration at once',
                        PRIMARY KEY (`id`),
                        KEY `library_id_idx` (`library_id`),
                        KEY `category_id_idx` (`category_id`),
                        KEY `item_type_idx` (`item_type`),
                        KEY `name_idx` (`name`),
                        KEY `type_idx` (`type`),
                        KEY `configuration_group_bit_idx` (`configuration_group_bit`),
                        UNIQUE KEY `config_scope_unique` (`library_id`, `category_id`, `item_type`, `name`),
                        CONSTRAINT `library_id_fk` FOREIGN KEY (`library_id`) REFERENCES `branches` (`branchcode`) ON DELETE CASCADE ON UPDATE CASCADE,
                        CONSTRAINT `category_id_fk` FOREIGN KEY (`category_id`) REFERENCES `categories` (`categorycode`) ON DELETE CASCADE ON UPDATE CASCADE,
                        CONSTRAINT `item_type_fk` FOREIGN KEY (`item_type`) REFERENCES `itemtypes` (`itemtype`) ON DELETE CASCADE ON UPDATE CASCADE,
                        CONSTRAINT `configuration_group_bit_fk` FOREIGN KEY (`configuration_group_bit`) REFERENCES `configuration_groups` (`bit`) ON DELETE CASCADE ON UPDATE CASCADE
                    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
                }
            );
        }
    },
};
