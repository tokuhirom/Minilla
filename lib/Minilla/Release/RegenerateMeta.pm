package Minilla::Release::RegenerateMeta;
use strict;
use warnings;
use utf8;
use File::pushd;
use Minilla::Project;

sub run {
    my ($self, $c, $opts, $project) = @_;

    my $guard = pushd($project->dir);

    my $meta = $project->cpan_meta('unstable');
    $meta->save('META.json', {
        version => 2.0,
    });
}

1;

