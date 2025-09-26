package Koha::BackgroundJob::BatchAddDisplayItems;

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
use Koha::Display;

use base 'Koha::BackgroundJob';

=head1 NAME

Koha::BackgroundJob::BatchAddDisplayItems - Background job to add multiple items to a display

=head1 API

=head2 Class methods

=head3 job_type

Return the job type 'batch_add_display_items'.

=cut

sub job_type {
    return 'batch_add_display_items';
}

=head3 process

Process the batch addition of items to a display

=cut

sub process {
    my ( $self, $args ) = @_;

    if ( $self->status eq 'cancelled' ) {
        return;
    }

    $self->start;

    my $display_id  = $args->{display_id};
    my @item_ids    = @{ $args->{item_ids} };
    my $date_remove = $args->{date_remove};

    my $report = {
        total_records => scalar @item_ids,
        total_success => 0,
        total_errors  => 0,
    };

    my @messages;
    my @added_items;
    my @failed_items;

    # Validate display exists
    my $display = Koha::Display->find($display_id);
    unless ($display) {
        push @messages, {
            type => 'error',
            code => 'display_not_found',
            display_id => $display_id,
        };
        $self->finish({ messages => \@messages, report => $report });
        return;
    }

    try {
        my $schema = Koha::Database->new->schema;
        $schema->txn_do(
            sub {
                for my $item_id ( sort { $a <=> $b } @item_ids ) {

                    last if $self->get_from_storage->status eq 'cancelled';

                    my $item = Koha::Items->find($item_id);
                    unless ($item) {
                        push @failed_items, {
                            itemnumber => $item_id,
                            error => 'Item not found'
                        };
                        $report->{total_errors}++;
                        next;
                    }

                    # Check if item is already in this display
                    my $existing = Koha::DisplayItems->search({
                        display_id => $display_id,
                        itemnumber => $item_id,
                    })->next;

                    if ($existing) {
                        push @failed_items, {
                            itemnumber => $item_id,
                            error => 'Item already in display'
                        };
                        $report->{total_errors}++;
                        next;
                    }

                    # Create display item
                    my $display_item = Koha::DisplayItem->new({
                        display_id   => $display_id,
                        itemnumber   => $item_id,
                        biblionumber => $item->biblionumber,
                        date_remove  => $date_remove,
                    })->store;

                    push @added_items, {
                        display_item_id => $display_item->display_item_id,
                        itemnumber => $item_id,
                        biblionumber => $item->biblionumber,
                    };

                    $report->{total_success}++;
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

    $report->{added_items} = \@added_items;
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

    return unless exists $args->{item_ids} && exists $args->{display_id};

    my @item_ids = @{ $args->{item_ids} };
    my $display_id = $args->{display_id};
    my $date_remove = $args->{date_remove};

    $self->SUPER::enqueue(
        {
            job_size => scalar @item_ids,
            job_args => {
                display_id  => $display_id,
                item_ids    => \@item_ids,
                date_remove => $date_remove,
            },
            job_queue => 'long_tasks',
        }
    );
}

1;