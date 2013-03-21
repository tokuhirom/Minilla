package Minya::CLI::Meta;
use strict;
use warnings;
use utf8;
use Path::Tiny;
use Minya::CPANMeta;

sub run {
    my ($self, @args) = @_;

    $self->parse_options(
        \@args,
    );

    my $meta = Minya::CPANMeta->new(
        config       => $self->config,
        prereq_specs => $self->prereq_specs,
    )->generate('unstable');
    $meta->save('META.json', {
        version => '2.0'
    });
}

1;

