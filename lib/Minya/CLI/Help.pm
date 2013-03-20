package Minya::CLI::Help;
use strict;
use warnings;
use utf8;

sub run {
    my ($self, @args) = @_;

    my $module = $args[0] ? ( "Minya::Doc::" . ucfirst $args[0] ) : "Minya";
    system "perldoc", $module;
}

1;

