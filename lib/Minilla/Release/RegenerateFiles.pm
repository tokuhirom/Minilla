package Minilla::Release::RegenerateFiles;
use strict;
use warnings;
use utf8;
use Minilla::Project;

sub run {
    my ($self, $project, $opts) = @_;

    $project->regenerate_files();
}

1;

