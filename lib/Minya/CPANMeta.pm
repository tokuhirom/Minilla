package Minya::CPANMeta;
use strict;
use warnings;
use utf8;
use CPAN::Meta;

use Moo;

has [qw(config prereq_specs)] => (
    is => 'ro',
    required => 1,
);

no Moo;

sub generate {
    my ($self, $release_status) = @_;

    my $dat = {
        "meta-spec" => {
            "version" => "2",
            "url"     => "http://search.cpan.org/perldoc?CPAN::Meta::Spec"
        },
        license        => $self->config->license_meta2,
        abstract       => $self->config->abstract,
        author         => [ $self->config->author ],
        dynamic_config => 0,
        version        => $self->config->version,
        name           => $self->config->dist_name,
        prereqs        => $self->prereq_specs,
        generated_by   => "Minya/$Minya::VERSION",
        release_status => $release_status || 'stable',
    };

    # TODO: provides

    my $meta = CPAN::Meta->new($dat);
    return $meta;
}

1;

