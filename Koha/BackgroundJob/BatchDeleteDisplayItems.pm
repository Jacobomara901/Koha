package Koha::BackgroundJob::BatchDeleteDisplayItems;

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;
use Try::Tiny qw( catch try );

use Koha::DisplayItem;
use Koha::DisplayItems;
use Koha::Items;

use base 'Koha::BackgroundJob';

=head1 NAME

Koha::BackgroundJob::BatchDeleteDisplayItems - Background job to remove multiple items from displays

=head1 API

=head2 Class methods

=head3 job_type

Return the job type 'batch_delete_display_items'.

=cut

sub job_type {
    return 'batch_delete_display_items';
}

=head3 process

Process the batch removal of items from displays

=cut

sub process {
    my ( $self, $args ) = @_;

    if ( $self->status eq 'cancelled' ) {
        return;
    }

    $self->start;

    my @item_ids   = @{ $args->{item_ids} };
    my $display_id = $args->{display_id}; # Optional: if specified, only remove from this display

    my $report = {
        total_records => scalar @item_ids,
        total_success => 0,
        total_errors  => 0,
    };

    my @messages;
    my @deleted_items;
    my @failed_items;

    try {
        my $schema = Koha::Database->new->schema;
        $schema->txn_do(
            sub {
                for my $item_id ( sort { $a <=> $b } @item_ids ) {

                    last if $self->get_from_storage->status eq 'cancelled';

                    # Build search criteria
                    my $search_criteria = { itemnumber => $item_id };
                    $search_criteria->{display_id} = $display_id if $display_id;

                    my $display_items = Koha::DisplayItems->search($search_criteria);

                    unless ($display_items->count) {
                        push @failed_items, {
                            itemnumber => $item_id,
                            error => $display_id ? 'Item not found in specified display' : 'Item not found in any display'
                        };
                        $report->{total_errors}++;
                        next;
                    }

                    my $deleted_count = 0;
                    my @deleted_from_displays;

                    while (my $display_item = $display_items->next) {
                        push @deleted_from_displays, {
                            display_id => $display_item->display_id,
                            display_item_id => $display_item->display_item_id,
                        };
                        $display_item->delete;
                        $deleted_count++;
                    }

                    if ($deleted_count > 0) {
                        push @deleted_items, {
                            itemnumber => $item_id,
                            displays_removed_from => \@deleted_from_displays,
                            count => $deleted_count,
                        };
                        $report->{total_success}++;
                    } else {
                        push @failed_items, {
                            itemnumber => $item_id,
                            error => 'No display items could be deleted'
                        };
                        $report->{total_errors}++;
                    }

                    $self->step;
                }
            }
        );
    } catch {
        warn $_;
        push @messages, {
            type => 'error',
            code => 'unknown',
            error => $_,
        };
        die "Something terrible has happened!" if ( $_ =~ /Rollback failed/ );
    };

    $report->{deleted_items} = \@deleted_items;
    $report->{failed_items} = \@failed_items;

    my $data = $self->decoded_data;
    $data->{messages} = \@messages;
    $data->{report} = $report;

    $self->finish($data);
}

=head3 enqueue

Enqueue the job.

=cut

sub enqueue {
    my ( $self, $args ) = @_;

    return unless exists $args->{item_ids};

    my @item_ids = @{ $args->{item_ids} };
    my $display_id = $args->{display_id}; # Optional

    $self->SUPER::enqueue(
        {
            job_size => scalar @item_ids,
            job_args => {
                item_ids   => \@item_ids,
                display_id => $display_id,
            },
            job_queue => 'long_tasks',
        }
    );
}

1;