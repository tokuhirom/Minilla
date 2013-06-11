package Minilla::CLI::Test;
use strict;
use warnings;
use utf8;
use File::pushd;

use Minilla::WorkDir;
use Minilla::Project;
use Minilla::Util qw(parse_options);

sub run {
    my ($self, @args) = @_;

    my $release   = 0;
    my $author    = 1;
    my $automated = 0;
    my $all       = 0;
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
    $project->verify_prereqs( [qw(develop test runtime)], $_ ) for qw(requires recommends);

    $ENV{RELEASE_TESTING}   =1 if $release   == 0;
    $ENV{AUTHOR_TESTING}    =1 if $author    == 0;
    $ENV{AUTOMATED_TESTING} =1 if $automated == 0;

    my $work_dir = $project->work_dir;
    my $code = $work_dir->dist_test(@args);
    exit $code;
}

1;
__END__

=head1 NAME

Minilla::CLI::Test - Run test cases

=head1 SYNOPSIS

    % minil test

        --release      enables the RELEASE_TESTING env variable
        --automated    enables the AUTOMATED_TESTING env variable
        --author       enables the AUTHOR_TESTING env variable (default
                       behavior)
        --all          enables the RELEASE_TESTING, AUTOMATED_TESTING and
                       AUTHOR_TESTING env variables

=head1 DESCRIPTION

This sub-command run test cases.

