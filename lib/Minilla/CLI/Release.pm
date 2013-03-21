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

