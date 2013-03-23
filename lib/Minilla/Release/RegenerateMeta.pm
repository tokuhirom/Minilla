package Minilla::Release::RegenerateMeta;
use strict;
use warnings;
use utf8;
use Minilla::Project;

sub run {
    my ($self, $c, $opts, $project) = @_;

    $project->regenerate_meta_json();
}

1;

