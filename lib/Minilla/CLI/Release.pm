package Minilla::CLI::Release;
use strict;
use warnings;
use utf8;
use Path::Tiny;
use ExtUtils::MakeMaker qw(prompt);
use CPAN::Uploader;

use Minilla::Util qw(edit_file);
use Minilla::WorkDir;

sub run {
    my ($self, @args) = @_;

    my $opts = {
        test => 1,
        bump => 1,
    };
    $self->parse_options(
        \@args,
        'test!' => \$opts->{test},
        'bump!' => \$opts->{bump},
        'trial!' => \$opts->{trial},
    );

    my @steps = qw(
        BumpVersion
        CheckChangeLog
        DistTest
        MakeDist
        Commit
        Tag
        UploadToCPAN
    );
    for (@steps) {
        my $klass = "Minilla::Release::$_";
        if (eval "require ${klass}; 1") {
            my $meth = "${klass}::run";
            $klass->run($self, $opts);
        } else {
            $self->error("Error while loading $_: $@");
        }
    }
}

1;
__END__

=head1 NAME

Minilla::CLI::Release - Release the module to CPAN!

=head1 SYNOPSIS

    % minil release

        --no-test         Do not run test scripts
        --no-bump         Do not bump up version

=head1 DESCRIPTION

This subcommand release the module to CPAN.

