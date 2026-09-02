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

use C4::Auth   qw( get_template_and_user haspermission );
use C4::Output qw( output_html_with_http_headers );
use C4::Context;

use Koha::Libraries;
use Koha::Patrons;

my $input = CGI->new;

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name => "tools/restore_deleted_borrowers.tt",
        query         => $input,
        type          => "intranet",
        flagsrequired => { tools => 'restore_deleted_borrowers', borrowers => 'list_borrowers' },
    }
);

unless ( C4::Context->preference('AllowDeletedPatronRestoration') ) {
    print $input->redirect("/cgi-bin/koha/errors/404.pl");
    exit;
}

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

output_html_with_http_headers $input, $cookie, $template->output;
