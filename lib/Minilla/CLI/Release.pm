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

    my $test = 1;
    $self->parse_options(
        \@args,
        'test!' => \$test,
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
            $klass->run($self, @args);
        } else {
            $self->error("Error while loading $_: $@");
        }
    }

    my $work_dir = Minilla::WorkDir->instance($self);
    $work_dir->dist($self, $test);

    # TODO commit
    # TODO tag
    # TODO push tags
}

1;

