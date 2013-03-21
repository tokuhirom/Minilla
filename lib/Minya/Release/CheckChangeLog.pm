package Minya::Release::CheckChangeLog;
use strict;
use warnings;
use utf8;
use Path::Tiny;
use ExtUtils::MakeMaker qw(prompt);
use Minya::Util qw(edit_file);

sub run {
    my ($self, $c) = @_;

    my $version = $c->config->metadata->version;

    until (path('Changes')->slurp =~ /^$version/m) {
        if (prompt("There is no $version, do you want to edit changes file?", 'y') =~ /y/i) {
            edit_file('Changes');
        } else {
            $c->error("Giving up!");
        }
    }
}

1;

