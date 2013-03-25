package Minilla::Release::Tag;
use strict;
use warnings;
use utf8;

use Minilla::Util qw(cmd);
use Minilla::Logger;

sub run {
    my ($self, $project, $opts) = @_;

    my $ver = $project->version;
    if ( $opts->{dry_run} ) {
        infof("DRY-RUN.  Would have tagged version $ver.\n");
        return;
    }

    cmd('git', 'tag', $ver);
    cmd('git', "push", 'origin', tag => $ver);
}

1;

