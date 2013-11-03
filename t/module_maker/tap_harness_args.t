use strict;
use warnings;
use utf8;
use Test::More;
use t::Util;

use Minilla::Profile::ModuleBuild;
use Minilla::Project;

test(sub {
    like(slurp('Build.PL'), qr{tap_harness_args\s*=>\s*{\s*"jobs"\s*=>\s*9\s*}});
});

done_testing;

sub test {
    my $code = shift;

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

    write_minil_toml({
        name => 'Acme-Foo',
        tap_harness_args => {
            jobs => 9,
        },
    });
    git_init_add_commit();
    Minilla::Project->new()->regenerate_files();
    git_init_add_commit();
    $code->();
}
