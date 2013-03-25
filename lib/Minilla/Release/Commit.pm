package Minilla::Release::Commit;
use strict;
use warnings;
use utf8;

use Minilla::Util qw(find_file cmd);
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
    my $branch = _get_branch()
        or return;
    $branch =~ s/\n//g;
    infof("Pushing to origin\n");
    cmd('git', 'push', 'origin', $branch);
}

sub _get_branch {
    open my $fh, '<', '.git/HEAD';
    chomp( my $head = do { local $/; <$fh> });
    close $fh;

    my ($branch) = $head =~ m!ref: refs/heads/(\S+)!;
    return $branch;
}

1;

