package Minya::CLI::Install;
use strict;
use warnings;
use utf8;
use Path::Tiny;

sub run {
    my ($self, @args) = @_;

    my $test = 1;
    $self->parse_options(
        \@args,
        'test!' => \$test,
    );

    my $tar = $self->build_dist($test);
    $self->cmd('cpanm', ($self->verbose ? '--verbose' : ()), $tar);
    path($tar)->remove unless $self->debug;
}

1;

