use strict;
use Test::More;

use Acme::FooXS;

is(Acme::FooXS::hello(), 'Hello, world!');

done_testing;

