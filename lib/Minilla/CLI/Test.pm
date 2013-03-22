package Minilla::CLI::Test;
use strict;
use warnings;
use utf8;
use File::pushd;

use Minilla::WorkDir;
use Minilla::Project;

sub run {
    my ($self, @args) = @_;

    $self->parse_options(
        \@args,
    );

    my $project = Minilla::Project->new(
        c => $self,
    );

    $project->verify_prereqs( [qw(develop test runtime)], $_ ) for qw(requires recommends);

    my $work_dir = $project->work_dir;
    my $guard = pushd($work_dir->dir);
    $self->cmd($project->config->{test_command} || 'prove -l -r t ' . (-d 'xt' ? 'xt' : ''));
}

1;
__END__

=head1 NAME

Minilla::CLI::Test - Run test cases

=head1 SYNOPSIS

    % minil test

=head1 DESCRIPTION

This subcommand run test cases.

