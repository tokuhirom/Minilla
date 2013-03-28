use strict;
use warnings;
use utf8;
use Test::More;
use Test::Requires 'Devel::PPPort';
use t::Util;

use File::Spec;
use File::Path;
use File::pushd;
use Minilla::Util qw(slurp);
use Minilla::Git;
use Minilla::Profile::XS;

my $lib = File::Spec->rel2abs('lib');
my $bin = File::Spec->rel2abs('script/minil');

rmtree('Acme-Foo');

Minilla::Profile::XS->new(
    dist => 'Acme-Foo',
    module => 'Acme::Foo',
    path => 'Acme/Foo.pm',
)->generate();
git_init_add_commit;

ok(-f 'Acme-Foo/Build.PL');
ok(-f 'Acme-Foo/lib/Acme/Foo.pm');
like(slurp('Acme-Foo/lib/Acme/Foo.pm'), qr{XSLoader});
ok(-f 'Acme-Foo/.travis.yml');
ok(-f 'Acme-Foo/t/00_compile.t');

{
    my $guard = pushd('Acme-Foo');
    is(minil('test'), 0);
}

rmtree('Acme-Foo');

done_testing;

sub minil {
    system($^X, "-I$lib", $bin, @_);
}
