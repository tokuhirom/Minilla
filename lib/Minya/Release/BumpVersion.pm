package Minya::Release::BumpVersion;
use strict;
use warnings;
use utf8;

sub run {
    my ($self, $c) = @_;

    # perl-revision command is included in Perl::Version.
    $c->cmd('perl-reversion', '-bump');
}

1;

