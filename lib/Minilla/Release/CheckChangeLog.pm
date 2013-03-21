package Minilla::Release::CheckChangeLog;
use strict;
use warnings;
use utf8;
use Path::Tiny;
use ExtUtils::MakeMaker qw(prompt);
use Minilla::Util qw(edit_file);

sub run {
    my ($self, $c) = @_;

    my $version = $c->config->metadata->version;

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

