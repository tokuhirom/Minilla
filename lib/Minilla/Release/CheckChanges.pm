package Minilla::Release::CheckChanges;
use strict;
use warnings;
use utf8;
use ExtUtils::MakeMaker qw(prompt);

use Minilla::Util qw(edit_file slurp);
use Minilla::Logger;

sub run {
    my ($self, $project, $opts) = @_;

    my $version = $project->version;

    if ($ENV{PERL_MINILLA_SKIP_CHECK_CHANGE_LOG}) {
        infof("Okay, you are debugging now.\n");
        return;
    }

    until (slurp('Changes') =~ /^\{\{\$NEXT\}\}\n+[ \t]+\S/m) {
        infof("No mention of version '%s' in changelog file 'Changes'\n", $version);
        if (prompt("Edit file?", 'y') =~ /y/i) {
            edit_file('Changes');
        } else {
            errorf("Giving up!\n");
        }
    }
}

1;

