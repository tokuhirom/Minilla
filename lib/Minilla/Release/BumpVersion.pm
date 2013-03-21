package Minilla::Release::BumpVersion;
use strict;
use warnings;
use utf8;

sub run {
    my ($self, $c, $opts) = @_;

    # perl-revision command is included in Perl::Version.
    if ($opts->{bump}) {
        $c->cmd('perl-reversion', '-bump');
    } else {
        $c->infof('Skipped bump up');
    }
}

1;

