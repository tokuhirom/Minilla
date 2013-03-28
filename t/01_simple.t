use strict;
use Test::More;

use Acme::Foo;

is(Acme::Foo::hello(), 'Hello, world!');

done_testing;

