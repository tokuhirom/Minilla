use strict;
use warnings;
use utf8;
use Test::More;
use t::Util;

use Minilla::Project;
use Minilla::Profile::ModuleBuildTiny;

my $guard = pushd(tempdir());

Minilla::Profile::ModuleBuildTiny->new(
    author => 'hoge',
    dist => 'Acme-Foo',
    module => 'Acme::Foo',
    path => 'Acme/Foo.pm',
    version => '0.01',
)->generate();
spew('minil.toml', <<'...');
name = "Acme-Foo"
...

git_init(); git_add('.'); git_commit('-m', 'initial import');

Minilla::Project->new()->regenerate_meta_json();

cmd($^X, 'Build.PL');

like(slurp('MYMETA.json'), qr(Module::Build::Tiny), 'Module::Build::Tiny is required');
like(slurp('MYMETA.yml'), qr(Module::Build::Tiny), 'Module::Build::Tiny is required');

done_testing;

