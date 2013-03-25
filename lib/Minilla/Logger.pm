package Minilla::Logger;
use strict;
use warnings;
use utf8;
use parent qw(Exporter);

use Term::ANSIColor qw(colored);
require Win32::Console::ANSI if $^O eq 'MSWin32';

use Minilla::Errors;

our @EXPORT = qw(debugf infof warnf errorf);

our $COLOR;

use constant { DEBUG => 1, INFO => 2, WARN => 3, ERROR => 4 };

our $Colors = {
    DEBUG,   => 'green',
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
    return if $type == DEBUG && !Minilla->debug;
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

sub debugf {
    _printf(@_, DEBUG);
}

sub errorf {
    my(@msg) = @_;
    _printf(@msg, ERROR);
    Minilla::Error::CommandExit->throw;
}

1;

