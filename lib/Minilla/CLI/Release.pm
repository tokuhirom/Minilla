package Minilla::CLI::Release;
use strict;
use warnings;
use utf8;
use Path::Tiny;
use ExtUtils::MakeMaker qw(prompt);

use Minilla::Util qw(edit_file require_optional);
use Minilla::WorkDir;

sub run {
    my ($self, @args) = @_;

    my $opts = {
        test => 1,
        trial => 0,
        dry_run => 0,
    };
    $self->parse_options(
        \@args,
        'test!' => \$opts->{test},
        'trial!' => \$opts->{trial},
        'dry-run!' => \$opts->{dry_run},
    );

    my $project = Minilla::Project->new(
        c => $self,
    );

    my @steps = qw(
        CheckUntrackedFiles
        BumpVersion
        CheckChangeLog
        RegenerateMeta
        DistTest
        MakeDist
        Commit
        Tag
        UploadToCPAN
    );
    my @klasses;
    # Load all step classes.
    for (@steps) {
        my $klass = "Minilla::Release::$_";
        if (eval "require ${klass}; 1") {
            push @klasses, $klass;
            $klass->init() if $klass->can('init');
        } else {
            $self->error("Error while loading $_: $@");
        }
    }
    # And run all steps.
    for my $klass (@klasses) {
        $klass->run($self, $opts, $project);
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

This subcommand release the module to CPAN.

