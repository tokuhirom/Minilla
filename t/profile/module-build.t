use strict;
use warnings;
use utf8;
use Test::More;
use t::Util;

use Minilla::Profile::ModuleBuild;
use Minilla::Project;

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
write_minil_toml('Acme::Foo');
git_init_add_commit();
Minilla::Project->new()->regenerate_files();
git_init_add_commit();

cmd($^X, 'Build.PL');

like(slurp('MYMETA.json'), qr(CPAN::Meta), 'CPAN::Meta is required');
like(slurp('MYMETA.yml'), qr(CPAN::Meta), 'CPAN::Meta is required');

like(slurp('.gitignore'), qr{!LICENSE});

done_testing;

