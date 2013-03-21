package Minilla::Errors;
use strict;
use warnings;
use utf8;

package Minilla::Error::CommandExit;
sub throw {
    my $class = shift;
    my $self = bless {}, $class;
    die $self;
}

1;

