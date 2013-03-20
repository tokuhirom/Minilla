package Minya::CLI::Dist;
use strict;
use warnings;
use utf8;

sub run {
    my ($self, @args) = @_;

    my $test = 1;
    $self->parse_options(
        \@args,
        'test!' => \$test,
    );

    $self->build_dist($test);
}

1;

