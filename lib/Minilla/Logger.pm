package Minilla::Logger;
use strict;
use warnings;
use utf8;
use parent qw(Exporter);

use Term::ANSIColor qw(colored);
require Win32::Console::ANSI if $^O eq 'MSWin32';

use Minilla::Errors;

our @EXPORT = qw(infof warnf errorf);

our $COLOR;

use constant { DEBUG => 0, INFO => 1, WARN => 2, ERROR => 3 };

our $Colors = {
    WARN,    => 'yellow',
    INFO,    => 'cyan',
    ERROR,   => 'red',
};

sub _printf {
    my $type = pop;
    my($temp, @args) = @_;
    _print(sprintf($temp, map { defined($_) ? $_ : '-' } @args), $type);
}

sub _print {
    my($msg, $type) = @_;
    $msg = colored $msg, $Colors->{$type} if defined $type && $COLOR;
    my $fh = $type && $type >= WARN ? *STDERR : *STDOUT;
    print {$fh} $msg;
}

sub infof {
    _printf(@_, INFO);
}

sub warnf {
    _printf(@_, WARN);
}

sub errorf {
    my(@msg) = @_;
    _printf(@msg, ERROR);
    Minilla::Error::CommandExit->throw;
}

1;

