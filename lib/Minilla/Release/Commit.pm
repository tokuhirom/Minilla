package Minilla::Release::Commit;
use strict;
use warnings;
use utf8;

sub run {
    my ($self, $c) = @_;

    my $config = Minilla::Config->load($c, find_file('minil.toml'));
    my $ver = $config->metadata->version;

    my $msg = "Checking in changes prior to tagging of version $ver.\n\nChangelog diff is:\n\n";
    $msg .= `git diff Changes`;

    if ($c->dry_run) {
        $c->infof("DRY-RUN.  Would have committed message of:\n----------------\n$msg\n-----------\n");
        return;
    }

    $c->cmd('git', 'commit', '-a', '-m', $msg);
}

1;

