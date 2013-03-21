use strict;
use warnings;
use utf8;
use Test::More;
use File::Spec;
use File::Path;

my $lib = File::Spec->rel2abs('lib');
my $bin = File::Spec->rel2abs('bin/minya');

rmtree('Acme-Foo');

is(minya('new', 'Acme::Foo'), 0);
chdir('Acme-Foo');

is(minya('test'), 0);
is(minya('dist'), 0);

done_testing;

sub minya {
    system($^X, "-I$lib", $bin, @_);
}
