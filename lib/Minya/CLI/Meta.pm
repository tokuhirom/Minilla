package Minya::CLI::Meta;
use strict;
use warnings;
use utf8;
use Path::Tiny;

sub run {
    my ($self, @args) = @_;

    $self->parse_options(
        \@args,
    );

    my $meta = $self->generate_meta();
    $meta->save('META.json', {
        version => '2.0'
    });
}

1;

