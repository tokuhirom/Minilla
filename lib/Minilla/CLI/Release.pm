package Minilla::CLI::Release;
use strict;
use warnings;
use utf8;
use ExtUtils::MakeMaker qw(prompt);

use Minilla::Util qw(edit_file require_optional parse_options);
use Minilla::WorkDir;
use Minilla::Logger;

sub run {
    my ($self, @args) = @_;

    my $opts = {
        test => 1,
        trial => 0,
        dry_run => 0,
    };
    parse_options(
        \@args,
        'test!' => \$opts->{test},
        'trial!' => \$opts->{trial},
        'dry-run!' => \$opts->{dry_run},
    );

    my $project = Minilla::Project->new();

    my @steps = qw(
        CheckUntrackedFiles
        CheckOrigin
        BumpVersion
        CheckChanges
        RegenerateFiles
        DistTest
        MakeDist

        UploadToCPAN

        RewriteChanges
        Commit
        Tag
    );
    my @klasses;
    # Load all step classes.
    for (@steps) {
        my $klass = "Minilla::Release::$_";
        if (eval "require ${klass}; 1") {
            push @klasses, $klass;
            $klass->init() if $klass->can('init');
        } else {
            errorf("Error while loading %s: %s\n", $_, $@);
        }
    }
    # And run all steps.
    for my $klass (@klasses) {
        $klass->run($project, $opts);
    }
}

1;
__END__

=head1 NAME

Minilla::CLI::Release - Release the module to CPAN!

=head1 SYNOPSIS

    % minil release

        --no-test         Do not run test scripts
        --trial           Trial release
        --dry-run         Dry run mode

=head1 DESCRIPTION

This sub-command release the module to CPAN.

