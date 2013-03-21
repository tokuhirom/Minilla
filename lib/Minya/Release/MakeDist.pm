package Minya::Release::MakeDist;
use strict;
use warnings;
use utf8;

sub run {
    my ($self, $c) = @_;

    my $work_dir = Minya::WorkDir->instance($c);
    $work_dir->dist;
}

1;


1;

