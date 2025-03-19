use utf8;
package Koha::Schema::Result::Configuration;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::Configuration

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<configurations>

=cut

__PACKAGE__->table("configurations");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

Unique ID of the configuration entry

=head2 library_id

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 1
  size: 10

Internal identifier for the library the config applies to. NULL means global

=head2 category_id

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 1
  size: 10

Internal identifier for the category the config applies to. NULL means global

=head2 item_type

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 1
  size: 10

Internal identifier for the item type the config applies to. NULL means global

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 32

Configuration entry name

=head2 value

  data_type: 'mediumtext'
  is_nullable: 1

Configuration entry value

=head2 type

  data_type: 'enum'
  default_value: 'text'
  extra: {list => ["text","boolean","integer"]}
  is_nullable: 0

Configuration entry type

=head2 configuration_group_bit

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

Configuration group this setting applies to. Used for getting/setting all settings grouped for a specific configuration at once

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "library_id",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 1, size => 10 },
  "category_id",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 1, size => 10 },
  "item_type",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 1, size => 10 },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 32 },
  "value",
  { data_type => "mediumtext", is_nullable => 1 },
  "type",
  {
    data_type => "enum",
    default_value => "text",
    extra => { list => ["text", "boolean", "integer"] },
    is_nullable => 0,
  },
  "configuration_group_bit",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<config_scope_unique>

=over 4

=item * L</library_id>

=item * L</category_id>

=item * L</item_type>

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint(
  "config_scope_unique",
  ["library_id", "category_id", "item_type", "name"],
);

=head1 RELATIONS

=head2 category

Type: belongs_to

Related object: L<Koha::Schema::Result::Category>

=cut

__PACKAGE__->belongs_to(
  "category",
  "Koha::Schema::Result::Category",
  { categorycode => "category_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 configuration_group_bit

Type: belongs_to

Related object: L<Koha::Schema::Result::ConfigurationGroup>

=cut

__PACKAGE__->belongs_to(
  "configuration_group_bit",
  "Koha::Schema::Result::ConfigurationGroup",
  { bit => "configuration_group_bit" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 item_type

Type: belongs_to

Related object: L<Koha::Schema::Result::Itemtype>

=cut

__PACKAGE__->belongs_to(
  "item_type",
  "Koha::Schema::Result::Itemtype",
  { itemtype => "item_type" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 library

Type: belongs_to

Related object: L<Koha::Schema::Result::Branch>

=cut

__PACKAGE__->belongs_to(
  "library",
  "Koha::Schema::Result::Branch",
  { branchcode => "library_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2025-03-16 15:50:39
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Xs76CyFZ2DMgV27R3g/NnQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
