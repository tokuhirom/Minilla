package Minilla::Release::DistTest;
use strict;
use warnings;
use utf8;

sub run {
    my ($self, $c) = @_;

    my $work_dir = Minilla::WorkDir->instance($c);
    $work_dir->dist_test;
}

1;

