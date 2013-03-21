use strict;
use warnings;
use utf8;
use Test::More;
use File::Spec;
use File::Path;
use File::pushd;

my $lib = File::Spec->rel2abs('lib');
my $bin = File::Spec->rel2abs('script/minil');

rmtree('Acme-Foo');

is(minil('new', 'Acme::Foo'), 0);
{
    my $guard = pushd('Acme-Foo');
    is(minil('meta'), 0);
    is(minil('test'), 0);
    is(minil('dist'), 0);
}

rmtree('Acme-Foo');

done_testing;

sub minil {
    system($^X, "-I$lib", $bin, @_);
}
