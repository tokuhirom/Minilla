package Minilla::CLI::Run;
use strict;
use warnings;
use utf8;

use Minilla::WorkDir;
use Minilla::Project;

sub run {
    my ($self, @args) = @_;

    my $project = Minilla::Project->new();
    my $work_dir = $project->work_dir;
    my $code = $work_dir->run(@args);
    exit $code;
}

1;
__END__

=head1 NAME

Minilla::CLI::Run - Run Arbitrary Commands

=head1 SYNOPSIS

    % minil run ...

=head1 DESCRIPTION

This sub-command allows you to run arbitrary commands on your build directory

=cut
