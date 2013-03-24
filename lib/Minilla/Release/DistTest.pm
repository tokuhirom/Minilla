package Minilla::Release::DistTest;
use strict;
use warnings;
use utf8;

sub run {
    my ($self, $c) = @_;

    local $ENV{RELEASE_TESTING} = 1;
    my $work_dir = Minilla::WorkDir->instance($c);
    $work_dir->dist_test;
}

1;

