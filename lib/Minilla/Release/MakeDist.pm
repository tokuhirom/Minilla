package Minilla::Release::MakeDist;
use strict;
use warnings;
use utf8;

sub run {
    my ($self, $project, $opts) = @_;

    my $work_dir = $project->work_dir();
    $work_dir->dist;
}

1;


1;

