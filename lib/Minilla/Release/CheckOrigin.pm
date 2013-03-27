package Minilla::Release::CheckOrigin;
use strict;
use warnings;
use utf8;
use Minilla::Logger;

sub run {
    my ($self, $project, $opts) = @_;

    unless (`git remote`) {
        errorf("No git remote.\n");
    }
}

1;

