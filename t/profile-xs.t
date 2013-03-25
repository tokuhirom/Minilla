use strict;
use warnings;
use utf8;
use Test::More;
use Test::Requires 'Devel::PPPort';

use File::Spec;
use File::Path;
use File::pushd;
use Minilla::Util qw(slurp);

my $lib = File::Spec->rel2abs('lib');
my $bin = File::Spec->rel2abs('script/minil');

rmtree('Acme-Foo');

is(minil('new', '--username=anonymous', '--email=foo@example.com',  '-p', 'XS', 'Acme::Foo'), 0);
ok(-f 'Acme-Foo/Build.PL');
ok(-f 'Acme-Foo/lib/Acme/Foo.pm');
like(slurp('Acme-Foo/lib/Acme/Foo.pm'), qr{XSLoader});
ok(-f 'Acme-Foo/.travis.yml');
ok(-f 'Acme-Foo/t/00_compile.t');

{
    my $guard = pushd('Acme-Foo');
    is( system( $^X, 'Build.PL' ), 0 );
    is( system( $^X, 'Build', 'build' ), 0 );
    is( system( $^X, 'Build', 'test' ),  0 );
}

# rmtree('Acme-Foo');

done_testing;

sub minil {
    system($^X, "-I$lib", $bin, @_);
}
