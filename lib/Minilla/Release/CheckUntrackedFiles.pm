package Minilla::Release::CheckUntrackedFiles;
use strict;
use warnings;
use utf8;

sub run {
    my ($self, $c) = @_;

    if ( my $unk = `git ls-files -z --others --exclude-standard` ) {
        $unk =~ s/\0/\n/g;
        $c->error("Unknown local files:\n$unk\n\nUpdate .gitignore, or git add them\n");
    }
}

1;

