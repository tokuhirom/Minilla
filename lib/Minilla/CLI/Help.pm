package Minilla::CLI::Help;
use strict;
use warnings;
use utf8;

sub run {
    my ($self, @args) = @_;

    my $module = $args[0] ? ( "Minilla::Doc::" . ucfirst $args[0] ) : "Minilla";
    system "perldoc", $module;
}

1;

