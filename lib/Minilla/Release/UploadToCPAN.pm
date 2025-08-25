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
    } elsif ($project->config->{release}->{do_not_upload_to_cpan}) {
        infof("You disabled CPAN uploading feature in minil.toml.\n");
    } else {
        infof("Upload to CPAN\n");

        my $pause_config = ($opts->{pause_config})          ? $opts->{pause_config}
            : ($project->config->{release}->{pause_config}) ? $project->config->{release}->{pause_config}
            :                                                 undef;
        my $config = CPAN::Uploader->read_config_file($pause_config);
        $config->{password} //= $ENV{CPAN_UPLOADER_UPLOAD_PASSWORD} // undef;
        if (!$config || !$config->{user} || !$config->{password}) {
            die <<EOF

Missing ~/.pause file or your ~/.pause file is wrong.
You should put ~/.pause file in following format.

    user {{YOUR_PAUSE_ID}}
    password {{YOUR_PAUSE_PASSWORD}}


EOF
        }

        PROMPT: while (1) {
            my $answer = prompt("Release to " . ($config->{upload_uri} || 'CPAN') . ' ? [y/n/s[hell]] ');
            if ($answer =~ /y/i) {
                last PROMPT;
            } elsif ($answer =~ /n/i) {
                errorf("Giving up!\n");
            } elsif ($answer =~ /^s/i) {
              print "tar file: $tar\n";
              system ($ENV{ SHELL } or 'sh');
              redo PROMPT;
            } else {
                redo PROMPT;
            }
        }

        if ($opts->{trial}) {
            my $orig_file = $tar;
            $tar =~ s/\.(tar\.gz|tgz|tar.bz2|tbz|zip)$/-TRIAL.$1/
            or die "Distfile doesn't match supported archive format: $orig_file";
            infof("renaming $orig_file -> $tar for TRIAL release\n");
            rename $orig_file, $tar or errorf("Renaming $orig_file -> $tar failed: $!\n");
        }

        my $uploader = CPAN::Uploader->new(+{
            tar => $tar,
            %$config
        });
        $uploader->upload_file($tar);
    }

    unlink($tar) unless Minilla->debug;
}

1;

