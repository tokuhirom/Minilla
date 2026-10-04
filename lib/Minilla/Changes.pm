package Minilla::Changes;
use strict;
use warnings;
use utf8;

sub is_prepared {
    my ($content, $version) = @_;

    return $content =~
        /^\{\{\$NEXT\}\}\h*\R(?:\h*\R)*\Q$version\E(?=\h|\R|\z)/m;
}

1;
