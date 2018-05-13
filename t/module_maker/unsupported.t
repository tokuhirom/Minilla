use strict;
use warnings;
use utf8;
use Test::More;
use lib "t/lib";
use Util;

use Minilla::Profile::ModuleBuild;
use Minilla::Project;

test(sub {
    like(slurp('Build.PL'), qr{^die "OS unsupported\\n" if \$\^O eq "MSWin32";$}m);
});

done_testing;

sub test {
    my $code = shift;

    my $guard = pushd(tempdir(CLEANUP => 1));

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
        module_maker => "ModuleBuild",
        unsupported => { os => [qw/MSWin32/] },
    });
    git_init_add_commit();
    Minilla::Project->new()->regenerate_files();
    git_init_add_commit();
    $code->();
}
