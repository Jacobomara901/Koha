#!/usr/bin/perl

use Modern::Perl;
use CGI qw ( -utf8 );
use C4::Context;
use C4::Auth   qw( get_template_and_user );
use C4::Output qw( output_html_with_http_headers );

my $input = CGI->new;

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name => "admin/shibboleth/shibboleth-home.tt",
        query         => $input,
        type          => "intranet",
        flagsrequired => { parameters => 'manage_identity_providers' },
    }
);

output_html_with_http_headers $input, $cookie, $template->output;
