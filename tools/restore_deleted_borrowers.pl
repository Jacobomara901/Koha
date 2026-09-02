#!/usr/bin/perl

# This file is part of Koha.
#
# Copyright 2024 Koha Development Team
#
# Koha is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 3
# of the License, or (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General
# Public License along with Koha; if not, see
# <https://www.gnu.org/licenses>

use Modern::Perl;
use CGI qw ( -utf8 );
use Try::Tiny;
use Scalar::Util qw( blessed );

use Koha::DateUtils qw( dt_from_string );
use C4::Auth        qw( get_template_and_user haspermission );
use C4::Output      qw( output_html_with_http_headers );
use C4::Context;

use Koha::Old::Patrons;
use Koha::Patron::Categories;
use Koha::Libraries;

my $input = CGI->new;
my $op    = $input->param('op') || 'search';

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name => "tools/restore_deleted_borrowers.tt",
        query         => $input,
        type          => "intranet",
        flagsrequired => { tools => 'restore_deleted_borrowers' },
    }
);

#check if the user can view patrons from any branch, or just their own
my $logged_in_patron = Koha::Patrons->find($loggedinuser);
my $can_view_all_libraries =
    haspermission( $logged_in_patron->userid, { borrowers => 'view_borrower_infos_from_any_libraries' } );

my @libraries;
if ($can_view_all_libraries) {

    # User can view all branches, get them all
    @libraries = Koha::Libraries->search( {}, { order_by => 'branchname' } )->as_list;
} else {

    # User can only view their branch or branches in the group, get only those
    @libraries = Koha::Libraries->search_filtered(
        { only_from_group => 1 },
        { order_by        => ['branchname'] }
    )->as_list;
}

$template->param(
    allowed_libraries      => \@libraries,
    can_view_all_libraries => $can_view_all_libraries,
);

if ( $op eq 'search' ) {

    # Get search parameters
    my $cardnumber     = $input->param('cardnumber');
    my $borrowernumber = $input->param('borrowernumber');
    my $surname        = $input->param('surname');
    my $firstname      = $input->param('firstname');
    my $email          = $input->param('email');
    my @categorycodes  = $input->multi_param('categorycode');
    my @branchcodes    = $input->multi_param('branchcode');
    my $deleted_from   = $input->param('deleted_from');
    my $deleted_to     = $input->param('deleted_to');

    # No empty searches, if no search critrea is added, do nothing.
    if (   $cardnumber
        || $borrowernumber
        || $surname
        || $firstname
        || $email
        || @categorycodes
        || @branchcodes
        || $deleted_from
        || $deleted_to )
    {

        # empty search parameters
        my %search_params;

        # these params should be exact matches
        $search_params{cardnumber}     = $cardnumber     if $cardnumber;
        $search_params{borrowernumber} = $borrowernumber if $borrowernumber;

        #multiselect params
        if (@categorycodes) {
            $search_params{categorycode} = { -in => \@categorycodes };
        }
        if (@branchcodes) {
            $search_params{branchcode} = { -in => \@branchcodes };
        }

        # these params don't necessarily have to be exact matches
        $search_params{surname}   = { 'like' => "%$surname%" }   if $surname;
        $search_params{firstname} = { 'like' => "%$firstname%" } if $firstname;
        $search_params{email}     = { 'like' => "%$email%" }     if $email;

        #date parameters
        my $dtf = Koha::Database->new->schema->storage->datetime_parser;
        if ( $deleted_from && $deleted_to ) {
            my $from_dt = dt_from_string($deleted_from);
            my $to_dt   = dt_from_string($deleted_to)->add( days => 1 );

            $search_params{updated_on} = {
                '>=' => $dtf->format_datetime($from_dt),
                '<'  => $dtf->format_datetime($to_dt)
            };
        } elsif ($deleted_from) {
            my $from_dt = dt_from_string($deleted_from);
            $search_params{updated_on} = { '>=' => $dtf->format_datetime($from_dt) };
        } elsif ($deleted_to) {
            my $to_dt = dt_from_string($deleted_to)->add( days => 1 );
            $search_params{updated_on} = { '<' => $dtf->format_datetime($to_dt) };
        }

        my $deleted_patrons_rs = Koha::Old::Patrons->search_limited(
            \%search_params,
            {
                order_by => { -desc => 'updated_on' },
                rows     => 100,
            }
        );

        my @deleted_patrons;

        while ( my $patron = $deleted_patrons_rs->next ) {

            #collect patron data to use in the results table
            my $patron_data = {
                borrowernumber => $patron->borrowernumber,
                cardnumber     => $patron->cardnumber,
                surname        => $patron->surname,
                firstname      => $patron->firstname,
                email          => $patron->email,
                branchcode     => $patron->branchcode,
                updated_on     => $patron->updated_on,
                categorycode   => $patron->categorycode,
            };

            push @deleted_patrons, $patron_data;
        }

        $template->param(
            view            => 'results',
            deleted_patrons => \@deleted_patrons,
            cardnumber      => $cardnumber,
            borrowernumber  => $borrowernumber,
            surname         => $surname,
            firstname       => $firstname,
            email           => $email,
            deleted_from    => $deleted_from,
            deleted_to      => $deleted_to,
        );
    } else {
        $template->param( view => 'search' );
    }

} elsif ( $op eq 'cud-restore' ) {

    my @borrowernumbers = $input->multi_param('borrowernumber');

    my @restored_patrons;
    my @errors;

    foreach my $borrowernumber (@borrowernumbers) {
        try {
            # Find the deleted patron
            my $deleted_patron = Koha::Old::Patrons->search_limited( { borrowernumber => $borrowernumber } )->next;

            unless ($deleted_patron) {
                push @errors, "Borrowernumber $borrowernumber not found in deleted patrons";
                next;
            }

            # Attempt to restore
            my $restored_patron = $deleted_patron->restore_deleted_borrower;

            push @restored_patrons, {
                borrowernumber => $restored_patron->borrowernumber,
                cardnumber     => $restored_patron->cardnumber,
                firstname      => $restored_patron->firstname,
                surname        => $restored_patron->surname,
                branchcode     => $restored_patron->branchcode,
                categorycode   => $restored_patron->categorycode,
            };
        } catch {
            push @errors, "Error restoring borrower $borrowernumber: $_";
        };
    }

    $template->param(
        view             => 'restored',
        restored_patrons => \@restored_patrons,
        errors           => \@errors,
    );

} else {
    $template->param( view => 'search' );
}

output_html_with_http_headers $input, $cookie, $template->output;
