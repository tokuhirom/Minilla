use strict;
use warnings;
use utf8;
use Test::More;

use Minilla::Gitignore;

my $gi = Minilla::Gitignore->new();
$gi->add('foo');
$gi->add('bar');
$gi->remove('foo');
is($gi->as_string(), "bar\n");

done_testing;

