package Minilla::CLI::Install;
use strict;
use warnings;
use utf8;

use Minilla::WorkDir;
use Minilla::Util qw(cmd parse_options);

sub run {
    my ($self, @args) = @_;

    my $test = 1;
    parse_options(
        \@args,
        'test!' => \$test,
    );

    my $project = Minilla::Project->new();
    my $work_dir = $project->work_dir();

    if ($test) {
        local $ENV{RELEASE_TESTING} = 1;
        $work_dir->dist_test();
    }
    my $tar = $work_dir->dist();

    cmd(
        'cpanm',
        '--notest',
        $tar
    );
    unlink($tar) unless Minilla->debug;
}

1;
__END__

=head1 NAME

Minilla::CLI::Install - Install the dist to system

=head1 SYNOPSIS

    % minil install

=head1 OPTIONS

=over 4

=item B<--no-test>, B<--notest>

Skip distribution tests. Both spellings are supported.

=back

=head1 DESCRIPTION

This sub-command install the dist for your system.
