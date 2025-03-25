use utf8;
package Koha::Schema::Result::ConfigurationGroup;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::ConfigurationGroup

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<configuration_groups>

=cut

__PACKAGE__->table("configuration_groups");

=head1 ACCESSORS

=head2 bit

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

Unique bit identifier

=head2 flag

  data_type: 'varchar'
  is_nullable: 0
  size: 32

The name/flag of this configuration group

=head2 flagdesc

  data_type: 'varchar'
  is_nullable: 0
  size: 255

Description of this configuration group

=cut

__PACKAGE__->add_columns(
  "bit",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "flag",
  { data_type => "varchar", is_nullable => 0, size => 32 },
  "flagdesc",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);

=head1 PRIMARY KEY

=over 4

=item * L</bit>

=back

=cut

__PACKAGE__->set_primary_key("bit");

=head1 UNIQUE CONSTRAINTS

=head2 C<flag>

=over 4

=item * L</flag>

=back

=cut

__PACKAGE__->add_unique_constraint("flag", ["flag"]);

=head1 RELATIONS

=head2 configurations

Type: has_many

Related object: L<Koha::Schema::Result::Configuration>

=cut

__PACKAGE__->has_many(
  "configurations",
  "Koha::Schema::Result::Configuration",
  { "foreign.configuration_group_bit" => "self.bit" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2025-03-16 15:50:39
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:QNhOkR2gc3UPLubI4Hfwlw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
