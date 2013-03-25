package Minilla::Release::UploadToCPAN;
use strict;
use warnings;
use utf8;
use ExtUtils::MakeMaker qw(prompt);

use Minilla::Util qw(require_optional);
use Minilla::Logger;

sub init {
    require_optional('CPAN/Uploader.pm',
        'Release engineering');
}

sub run {
    my ($self, $project, $opts) = @_;

    my $work_dir = $project->work_dir();
    my $tar = $work_dir->dist;

    if ($opts->{dry_run} || $ENV{FAKE_RELEASE}) {
        infof("Dry run. You don't need the module upload to CPAN\n");
    } else {
        infof("Upload to CPAN\n");

        unless (prompt("Release to CPAN?", 'y') =~ /y/i) {
            errorf("Giving up!\n");
        }

        if ($opts->{trial}) {
            my $orig_file = $tar;
            $tar =~ s/\.(tar\.gz|tgz|tar.bz2|tbz|zip)$/-TRIAL.$1/
            or die "Distfile doesn't match supported archive format: $orig_file";
            infof("renaming $orig_file -> $tar for TRIAL release\n");
            rename $orig_file, $tar or errorf("Renaming $orig_file -> $tar failed: $!\n");
        }

        my $config = CPAN::Uploader->read_config_file();
        my $uploader = CPAN::Uploader->new(+{
            tar => $tar,
            %$config
        });
        $uploader->upload_file($tar);
    }

    unlink($tar) unless Minilla->debug;
}

1;

