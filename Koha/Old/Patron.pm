package Koha::Old::Patron;

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
# along with Koha; if not, see <https://www.gnu.org/licenses>.

use Modern::Perl;

use C4::Log qw( logaction );

use base qw(Koha::Object);

=head1 NAME

Koha::Old::Patron - Koha Old::Patron Object class

=head1 API

=head2 Class methods

=cut

=head3 restore_deleted_borrower

    my $patron = $old_patron->restore_deleted_borrower;

Restores a deleted patron from the deletedborrowers table back to the borrowers table.
This only restores the patron account record itself, not any associated historical data.
The patron will retain their original borrowernumber.

Returns the restored Koha::Patron object on success.
Throws an exception on failure.

=cut

sub restore_deleted_borrower {
    my ($self) = @_;

    my $schema = Koha::Database->new->schema;
    my $restored_patron;

    # Check if borrowernumber exists in borrowers. If it does thrown an exception, cannot restore.
    my $existing_borrower = Koha::Patrons->find( $self->borrowernumber );
    if ($existing_borrower) {
        Koha::Exceptions::Patron::CannotRestore->throw(
            error => 'Borrowernumber already exists',
            type  => 'borrowernumber',
        );
    }

    # Check if cardnumber exists in borrowers. If it does thrown an exception, cannot restore.
    my $existing_cardnumber = Koha::Patrons->find( { cardnumber => $self->cardnumber } );
    if ($existing_cardnumber) {
        Koha::Exceptions::Patron::CannotRestore->throw(
            error => 'Cardnumber already in use',
            type  => 'cardnumber',
        );
    }

    # Check if userid exists. If it does thrown an exception, cannot restore.
    if ( $self->userid ) {
        my $existing_userid = Koha::Patrons->find( { userid => $self->userid } );
        if ($existing_userid) {
            Koha::Exceptions::Patron::CannotRestore->throw(
                error => 'Username already in use',
                type  => 'userid',
            );
        }
    }

    $schema->txn_do(
        sub {
            # Retrieve all the data about this patron from deleteborrowers table
            my $patron_data = $self->unblessed;

            # some fields must be cleared
            # borrower_debarments table is cleared on delete, we must also removed the debarment from the patron record
            $patron_data->{debarred}        = undef;
            $patron_data->{debarredcomment} = undef;

            #dont restore borrowers with flags, those will have to be re-added
            $patron_data->{flags} = undef;

            # Create the Koha::Patron object
            my $patron = Koha::Patron->new($patron_data);

            # Create the "new" patron using SUPER::store to bypass any Koha::Patron->store() and restore the patron as it was
            $restored_patron = $patron->SUPER::store();

            # Delete the entry from deletedborrowers
            Koha::Old::Patrons->search( { borrowernumber => $patron_data->{borrowernumber} } )->delete;

            # Log the restoration
            logaction(
                'MEMBERS',
                'Restore',
                $restored_patron->borrowernumber,
                "Patron restored from deletedborrowers: " . $restored_patron->cardnumber
            ) if C4::Context->preference('BorrowersLog');

        }
    );

    return $restored_patron;
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'Deletedborrower';
}

1;
