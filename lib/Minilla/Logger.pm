package Minilla::Logger;
use strict;
use warnings;
use utf8;
use parent qw(Exporter);

use JSON::PP ();
use Term::ANSIColor qw(colored);
require Win32::Console::ANSI if $^O eq 'MSWin32';

use Minilla::Errors;

our @EXPORT = qw(debugf infof warnf errorf slog);

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
    print STDERR $msg;
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

sub slog {
    print STDOUT JSON::PP->new->ascii->encode(shift), "\n";
}

sub errorf {
    my(@msg) = @_;
    _printf(@msg, ERROR);

    my $fmt = shift @msg;
    Minilla::Error::CommandExit->throw(sprintf($fmt, @msg));
}

1;

=head1 NAME

Minilla::Logger - Minilla logging functions

=head1 FUNCTIONS

=head2 slog

    slog({ event => 'build', status => 'success' });

Writes the supplied hash reference as a single JSON object followed by a
newline to standard output. Nested arrays and hashes are supported, and
undefined values become JSON null. Pass an empty hash reference to write an
empty object. JSON encoding errors propagate to the caller.

Strings are escaped, including embedded newlines and non-ASCII characters,
so each call produces one physical line regardless of the output encoding.
Unlike the formatted logging functions, C<slog> always writes to standard
output and is not affected by color or debug settings.

=cut
