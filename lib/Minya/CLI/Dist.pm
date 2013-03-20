package Minya::CLI::Dist;
use strict;
use warnings;
use utf8;
use Minya::WorkDir;

sub run {
    my ($self, @args) = @_;

    my $test = 1;
    $self->parse_options(
        \@args,
        'test!' => \$test,
    );

    Minya::WorkDir->make_tar_ball($self, $test);
}

1;

