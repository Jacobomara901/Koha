use utf8;
package Koha::Schema::Result::OpacBrowseResult;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::OpacBrowseResult

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<opac_browse_results>

=cut

__PACKAGE__->table("opac_browse_results");

=head1 ACCESSORS

=head2 session_id

  data_type: 'varchar'
  is_nullable: 0
  size: 32

CGISESSID of the session this browse-results set belongs to

=head2 busc

  data_type: 'longtext'
  is_nullable: 1

Encoded OpacBrowseResults paging data (search criteria and result biblionumbers)

=head2 updated_on

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

Date and time this row was last written, used for cleanup

=cut

__PACKAGE__->add_columns(
  "session_id",
  { data_type => "varchar", is_nullable => 0, size => 32 },
  "busc",
  { data_type => "longtext", is_nullable => 1 },
  "updated_on",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</session_id>

=back

=cut

__PACKAGE__->set_primary_key("session_id");


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2026-06-22 11:01:32
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:uwLmWZn1WYC//yaSZm96CQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
