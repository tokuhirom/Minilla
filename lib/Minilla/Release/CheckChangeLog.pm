package Minilla::Release::CheckChangeLog;
use strict;
use warnings;
use utf8;
use Path::Tiny;
use ExtUtils::MakeMaker qw(prompt);

use Minilla::Util qw(edit_file);
use Minilla::Logger;

sub run {
    my ($self, $project, $opts) = @_;

    my $version = $project->version;
       $version =~ s/^v//;

    if ($ENV{PERL_MINILLA_SKIP_CHECK_CHANGE_LOG}) {
        infof("Okay, you are debugging now.\n");
        return;
    }

    until (path('Changes')->slurp =~ /^\{\{\$NEXT\}\}\n+[ \t]+\S/m) {
        infof("No mention of version '%s' in changelog file 'Changes'\n", $version);
        if (prompt("Edit file?", 'y') =~ /y/i) {
            edit_file('Changes');
        } else {
            errorf("Giving up!\n");
        }
    }
}

sub after_release {
    my ($self, $project, $opts) = @_;
    return if $opts->{dry_run};

    my $content = path('Changes')->slurp_raw();
    $content =~ s!{{\$NEXT}}!
        "{{\$NEXT}}\n\n" . $project->version . " " . $project->work_dir->changes_time->strftime('%Y-%m-%dT%H:%M:%SZ') . "\n"
    !e;
    path('Changes')->spew_raw($content);
}

1;

