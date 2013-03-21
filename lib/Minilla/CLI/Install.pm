package Minilla::CLI::Install;
use strict;
use warnings;
use utf8;
use Path::Tiny;
use Minilla::WorkDir;

sub run {
    my ($self, @args) = @_;

    my $test = 1;
    $self->parse_options(
        \@args,
        'test!' => \$test,
    );

    my $tar = Minilla::WorkDir->make_tar_ball($self, $test);
    $self->cmd('cpanm', ($self->verbose ? '--verbose' : ()), $tar);
    path($tar)->remove unless $self->debug;
}

1;

