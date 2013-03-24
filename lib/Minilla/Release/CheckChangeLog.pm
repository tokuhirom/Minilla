package Minilla::Release::CheckChangeLog;
use strict;
use warnings;
use utf8;
use Path::Tiny;
use ExtUtils::MakeMaker qw(prompt);

use Minilla::Util qw(edit_file);

sub run {
    my ($self, $c, $opts, $project) = @_;

    my $version = $project->version;
       $version =~ s/^v//;

    if ($ENV{PERL_MINILLA_SKIP_CHECK_CHANGE_LOG}) {
        $c->infof("Okay, you are debugging now.\n");
        return;
    }

    until (path('Changes')->slurp =~ /^$version/m) {
        $c->infof("No mention of version '$version' in changelog file 'Changes'\n");
        if (prompt("Edit file?", 'y') =~ /y/i) {
            edit_file('Changes');
        } else {
            $c->error("Giving up!");
        }
    }
}

1;

