package Minilla::Release::RegenerateMeta;
use strict;
use warnings;
use utf8;
use Minilla::Project;

sub run {
    my ($self, $project, $opts) = @_;

    $project->regenerate_meta_json();
}

1;

