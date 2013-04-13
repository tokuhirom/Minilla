package Minilla::Errors;
use strict;
use warnings;
use utf8;

use Carp ();

package Minilla::Error::CommandExit;

use overload '""' => 'message', fallback => 1;

sub throw {
    my $class = shift;
    my $self = bless { message => Carp::longmess($class) }, $class;
    die $self;
}

sub message {
    my($self) = @_;
    return $self->{message};
}

1;

