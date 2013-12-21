package Minilla::Release::Commit;
use strict;
use warnings;
use utf8;

use Minilla::Util qw(find_file cmd get_branch);
use Minilla::Logger;

sub run {
    my ($self, $project, $opts) = @_;

    my @modified_files = split /\0/, `git ls-files --deleted --modified -z`;
    return if @modified_files == 0;

    $project->clear_metadata();
    my $ver = $project->metadata->version;

    my $msg = "Checking in changes prior to tagging of version $ver.\n\nChangelog diff is:\n\n";
    $msg .= `git diff Changes`;

    if ($opts->{dry_run}) {
        infof("DRY-RUN.  Would have committed message of:\n----------------\n$msg\n-----------\n");
        return;
    }

    cmd('git', 'commit', '-a', '-m', $msg);

    $self->_push_to_origin();
}

sub _push_to_origin {
    my ($self) = @_;

    # git v1.7.10 is required?
    my $branch = get_branch()
        or return;
    infof("Pushing to origin\n");
    cmd('git', 'push', 'origin', $branch);
}

1;

