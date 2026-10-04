package Minilla::CLI::Test;
use strict;
use warnings;
use utf8;
use File::pushd;

use Minilla::WorkDir;
use Minilla::Project;
use Minilla::Util qw(check_git parse_options);

sub run {
    my ($self, @args) = @_;

    my $release   = 0;
    my $author    = 1;
    my $automated = 0;
    my $all       = 0;

    check_git;

    parse_options(
        \@args,
        'release!'   => \$release,
        'author!'    => \$author,
        'automated!' => \$automated,
        'all!'       => \$all,
    );

    if ($all) {
        $release = $author = $automated = 1;
    }

    my $project = Minilla::Project->new();
    $project->verify_prereqs( );

    $ENV{RELEASE_TESTING}   =1 if $release;
    $ENV{AUTHOR_TESTING}    =1 if $author;
    $ENV{AUTOMATED_TESTING} =1 if $automated;

    my $work_dir = $project->work_dir;
    my $code = $work_dir->dist_test();
    exit $code;
}

1;
__END__

=head1 NAME

Minilla::CLI::Test - Run test cases

=head1 SYNOPSIS

    % minil test

=head1 OPTIONS

=over 4

=item B<--release>

Set C<RELEASE_TESTING> while running tests.

=item B<--automated>

Set C<AUTOMATED_TESTING> while running tests.

=item B<--no-author>

Prevent Minilla from setting C<AUTHOR_TESTING>, which it sets by default.

=item B<--all>

Set C<RELEASE_TESTING>, C<AUTOMATED_TESTING>, and C<AUTHOR_TESTING>.

=back

=head1 DESCRIPTION

This sub-command run test cases.
