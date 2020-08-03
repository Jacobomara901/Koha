package Koha::Configurations;

# Copyright Theke Solutions 2020
#
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

use Koha::Configuration;
use Koha::Exceptions;

use base qw(Koha::Objects);

=head1 NAME

Koha::Configurations - Koha Configuration Object set class

=head1 API

=head2 Class methods

=head3 get_effective_config

    my $config = Koha::Configurations->get_effective_config(
        {
            name        => $name,
            library_id  => $library_id,
            category_id => $category_id,
            item_type   => $item_type
        }
    );

Get the effective configuration value for I<name>, given the specified parameters.
B<undef> means no specific parameter needs to be queried.

I<name> is mandatory and an exception will be thrownif omitted.

=cut

sub get_effective_config {
    my ( $self, $params ) = @_;

    my $name = $params->{name};
    Koha::Exceptions::MissingParameter->throw(
        "Required parameter 'name' missing")
      unless $name;

    $params->{category_id} //= undef;
    $params->{library_id}  //= undef;
    $params->{item_type}   //= undef;

    my $category_id = $params->{category_id};
    my $item_type   = $params->{item_type};
    my $library_id  = $params->{library_id};

    my $order_by = $params->{order_by}
      // { -desc => [ 'library_id', 'category_id', 'item_type' ] };

    my $search_params;
    $search_params->{name} = $name;

    $search_params->{category_id} =
      defined $category_id ? [ $category_id, undef ] : undef;
    $search_params->{item_type} =
      defined $item_type ? [ $item_type, undef ] : undef;
    $search_params->{library_id} =
      defined $library_id ? [ $library_id, undef ] : undef;

    my $config = $self->search(
        $search_params,
        {
            order_by => $order_by,
            rows     => 1,
        }
    )->single;

    return $config;
}

=head3 get_effective_configs

    my $configs = Koha::Configurations->get_effective_configs(
        {
            names => [
                'smtp_host',
                'smtp_port',
                'smtp_ssl'
            ],
            library_id  => $library_id,
            category_id => $category_id,
            item_type   => $item_type
        }
    );

Get the effective configuration values for the specified I<names>, given the specified
parameters. B<undef> means no specific parameter needs to be queried.

=cut

sub get_effective_configs {
    my ( $self, $params ) = @_;

    my $names       = $params->{names};
    my $category_id = $params->{category_id};
    my $item_type   = $params->{item_type};
    my $library_id  = $params->{library_id};

    my $configs;
    foreach my $name (@$names) {
        my $effective_conf = $self->get_effective_conf(
            {
                name        => $name,
                category_id => $category_id,
                item_type   => $item_type,
                library_id  => $library_id,
            }
        );

        $configs->{$name} = $effective_conf->get_value if $effective_conf;
    }

    return $configs;
}

=head3 set_config

    my $config = Koha::Configurations->set_config(
        {
            name        => $name,
            library_id  => $library_id,
            category_id => $category_id,
            item_type   => $item_type,
            type        => $config_entry_type
        }
    );

Sets the configuration value for I<name>, given the specified parameters.
B<undef> means no specific parameter needs to be queried.

I<name> and I<type> are mandatory and an exception will be thrownif omitted.

B<type> can currently take the following values:
- text
- boolean
- integer

=cut

sub set_config {
    my ( $self, $params ) = @_;

    for my $mandatory_parameter (qw( name value )) {
        Koha::Exceptions::MissingParameter->throw(
            "Required parameter '$mandatory_parameter' missing")
          unless exists $params->{$mandatory_parameter};
    }

    my $library_id  = $params->{library_id};
    my $category_id = $params->{category_id};
    my $item_type   = $params->{item_type};
    my $name        = $params->{name};
    my $value       = $params->{value};
    my $type        = $params->{type};

    my $config = $self->search(
        {
            name        => $name,
            library_id  => $library_id,
            category_id => $category_id,
            item_type   => $item_type,
        }
    )->next();

    if ($config) {
        $config->set( { value => $value } )->store;
    }
    else {
        $config = Koha::Configuration->new(
            {
                library_id  => $library_id,
                category_id => $category_id,
                item_type   => $item_type,
                name        => $name,
                value       => $value,
                type        => $type
            }
        )->store;
    }

    return $config;
}

=head3 set_configs

=cut

sub set_configs {
    my ( $self, $params ) = @_;

    my %set_params;
    $set_params{library_id} = $params->{library_id}
      if exists $params->{library_id};
    $set_params{category_id} = $params->{category_id}
      if exists $params->{category_id};
    $set_params{item_type} = $params->{item_type}
      if exists $params->{item_type};
    my $configs = $params->{configs};

    my $config_objects = [];
    while ( my ( $rule_name, $rule_value ) = each %$configs ) {
        my $config_object = Koha::Configurations->set_config(
            {
                %set_params,
                name  => $rule_name,
                value => $rule_value,
            }
        );
        push( @$config_objects, $config_object );
    }

    return $config_objects;
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'Configuration';
}

=head3 object_class

=cut

sub object_class {
    return 'Koha::Configuration';
}

1;
