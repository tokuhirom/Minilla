package Acme::FooXS;
use strict;
use warnings;
use 5.008005;
our $VERSION = "v0.0.55";

use XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

1;
__END__

=encoding utf-8

=head1 NAME

Acme::FooXS - It's new $module

=head1 SYNOPSIS

    use Acme::FooXS;

=head1 DESCRIPTION

Acme::FooXS is ...

=head1 LICENSE

Copyright (C) Fuji, Goro

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Fuji, Goro E<lt>g.psy.va@gmail.comE<gt>

