use strict;
use warnings;
use utf8;
use Test::More;
use t::Util;

use Minilla::Profile::ModuleBuild;

my $guard = pushd(tempdir());

Minilla::Profile::ModuleBuild->new(
    author => 'hoge',
    dist => 'Acme-Foo',
    module => 'Acme::Foo',
    path => 'Acme/Foo.pm',
    version => '0.01',
)->generate();

spew('MANIFEST', <<'...');
Build.PL
lib/Acme/Foo.pm
...

cmd($^X, 'Build.PL');

like(slurp('MYMETA.json'), qr(Module::CPANfile), 'Module::CPANfile is required');
like(slurp('MYMETA.yml'), qr(Module::CPANfile), 'Module::CPANfile is required');

done_testing;

