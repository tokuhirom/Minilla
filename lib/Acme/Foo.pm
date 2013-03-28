package Acme::Foo;
use strict;
use warnings;
use 5.008005;
our $VERSION = "0.01";

use XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

1;
__END__

=head1 NAME

Acme::Foo - It's new $module

=head1 SYNOPSIS

    use Acme::Foo;

=head1 DESCRIPTION

Acme::Foo is ...

=head1 LICENSE

Copyright (C) tokuhirom

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

tokuhirom E<lt>tokuhirom@gmail.comE<gt>

