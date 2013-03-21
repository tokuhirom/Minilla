package Minilla::Release::Commit;
use strict;
use warnings;
use utf8;

sub run {
    my ($self, $c) = @_;

    my $ver = $c->config->metadata->version;

    if ( my $unk = `git ls-files -z --others --exclude-standard` ) {
        $unk =~ s/\0/\n/g;
        $c->error("Unknown local files:\n$unk\n\nUpdate .gitignore, or git add them\n");
    }

    my $msg = "Checking in changes prior to tagging of version $ver.\n\nChangelog diff is:\n\n";
    $msg .= `git diff Changes`;

    if ($c->dry_run) {
        $c->infof("DRY-RUN.  Would have committed message of:\n----------------\n$msg\n-----------\n");
        return;
    }

    $c->cmd('git', 'commit', '-a', '-m', $msg);
}

1;

