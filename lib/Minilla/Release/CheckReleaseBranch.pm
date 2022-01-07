package Minilla::Release::CheckReleaseBranch;
use strict;
use warnings;
use utf8;
use Minilla::Logger;

sub run {
    my ($self, $project, $opts) = @_;

    # The checking only performs when the config explicitly sets the release branch.
    # That's why we don't use "$project->release_branch".
    my $release_branch = $project->config->{release}->{branch};
    return unless $release_branch;

    my $current_branch = `git rev-parse --abbrev-ref HEAD`;
    chomp $current_branch;
    unless ($current_branch eq $release_branch) {
        errorf("Release branch must be $release_branch.\n");
    }
}

1;

