package Minilla::Release::BumpVersion;
use strict;
use warnings;
use utf8;
use ExtUtils::MakeMaker qw(prompt);

sub run {
    my ($self, $c, $opts) = @_;

    # perl-revision command is included in Perl::Version.
    if ($opts->{bump}) {
        my $answer = prompt("How bump up version? 0: none, 1: major, 2: minor, 3: patch", 3);
        my @opts;
        if ($answer =~ /\A[1-3]\z/) {
            push @opts, +{
                1 => '-bump-revision',
                2 => '-bump-version',
                3 => '-bump-subversion',
            }->{$answer};
        }
        if ($opts->{dry_run}) {
            push @opts, '-dryrun';
        }
        $c->cmd('perl-reversion', @opts);
    } else {
        $c->infof('Skipped bump up');
    }
}

1;

