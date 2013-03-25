package Minilla::Release::CheckUntrackedFiles;
use strict;
use warnings;
use utf8;

use Minilla::Logger;

sub run {
    my ($self, $project, $opts) = @_;

    if ( my $unk = `git ls-files -z --others --exclude-standard` ) {
        $unk =~ s/\0/\n/g;
        errorf("Unknown local files:\n$unk\n\nUpdate .gitignore, or git add them\n");
    }
}

1;

