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

    while (1) {
        my $changes = slurp('Changes');
        last if $changes =~ /^\{\{\$NEXT\}\}\h*\R+\h+\S/m;

        # Tell the user what the problem is
        if ($changes !~ /\{\{\$NEXT\}\}/m) {
            infof("No mention of {{\$NEXT}} in changelog file 'Changes'\n");
        } elsif ($changes !~ /^\{\{\$NEXT\}\}/m) {
            infof("{{\$NEXT}} must be at the beginning of a line in changelog file 'Changes'\n");
        } elsif ($changes !~ /^\{\{\$NEXT\}\}\h*\R/m) {
            infof("{{\$NEXT}} in changelog file 'Changes' must be the only non-whitespace on its line\n");
        } else {
            infof("{{\$NEXT}} in changelog file 'Changes' must be followed by at least one indented line describing a change\n");
        }

        if (prompt("Edit file?", 'y') =~ /y/i) {
            edit_file('Changes');
        } else {
            errorf("Giving up!\n");
        }
    }
}

1;
