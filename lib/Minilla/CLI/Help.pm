package Minilla::CLI::Help;
use strict;
use warnings;
use utf8;

sub run {
    my ($self, @args) = @_;

    my $module = $args[0] ? ( "Minilla::CLI::" . ucfirst $args[0] ) : "Minilla";
    system "perldoc", $module;
}

1;
__END__

=head1 NAME

Minilla::CLI::Help - Help me!

=head1 SYNOPSIS

    # show help for minil itself
    minil help

    # show help page for `install` sub-command
    minil help install

