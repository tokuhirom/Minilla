package Minilla::Release::Commit;
use strict;
use warnings;
use utf8;
use Minilla::Util qw(find_file);

sub run {
    my ($self, $c) = @_;

    my $project = Minilla::Project->new(
        c => $c,
    );
    my $ver = $project->metadata->version;

    my $msg = "Checking in changes prior to tagging of version $ver.\n\nChangelog diff is:\n\n";
    $msg .= `git diff Changes`;

    if ($c->dry_run) {
        $c->infof("DRY-RUN.  Would have committed message of:\n----------------\n$msg\n-----------\n");
        return;
    }

    $c->cmd('git', 'commit', '-a', '-m', $msg);

    $self->_push_to_origin($c);
}

sub _push_to_origin {
    my ($self, $c) = @_;

    # git v1.7.10 is required?
    my $branch = `git symbolic-ref --short HEAD`
        or return;
    $branch =~ s/\n//g;
    $c->infof("Pushing to origin\n");
    $c->cmd('git', 'push', 'origin', $branch);
}

1;

