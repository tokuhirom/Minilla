package Minilla::Release::CheckOrigin;
use strict;
use warnings;
use utf8;
use Minilla::Logger;

sub run {
    my ($self, $project, $opts) = @_;

    my $remotes = `git remote`;
    if ($remotes !~ /^origin$/m) {
        errorf("No git remote named origin.\n");
    }
}

1;

