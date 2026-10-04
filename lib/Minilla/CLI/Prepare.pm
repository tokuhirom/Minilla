package Minilla::CLI::Prepare;
use strict;
use warnings;
use utf8;

use Minilla::Logger;
use Minilla::Project;
use Minilla::Release::BumpVersion;
use Minilla::Release::CheckChanges;
use Minilla::Release::RegenerateFiles;
use Minilla::Release::RewriteChanges;

sub run {
    my ($self, @args) = @_;

    my $version = shift @args;
    errorf("Too many arguments for prepare\n") if @args;

    my $project = Minilla::Project->new();
    return unless $project->validate();

    my $opts = {
        version => $version,
        dry_run => 0,
    };

    Minilla::Release::BumpVersion->init();
    Minilla::Release::BumpVersion->run($project, $opts);
    Minilla::Release::CheckChanges->run($project, $opts) if $project->manage_changes;
    Minilla::Release::RegenerateFiles->run($project, $opts);
    Minilla::Release::RewriteChanges->run($project, $opts) if $project->manage_changes;
}

1;
__END__

=head1 NAME

Minilla::CLI::Prepare - Prepare the source tree for release

=head1 SYNOPSIS

    % minil prepare
    % minil prepare v1.2.3

=head1 DESCRIPTION

This sub-command updates the distribution version, regenerates repository files,
and prepares F<Changes> when Minilla manages it.

It does not commit changes, create a Git tag, build a distribution archive,
upload to CPAN, or push anything.

