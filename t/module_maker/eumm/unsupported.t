use strict;
use warnings;
use utf8;
use Test::More;
use lib "t/lib";
use Util;

use Minilla::Profile::ModuleBuild;
use Minilla::Project;

test(sub {
    my $mf = slurp('Makefile.PL');
    like($mf, qr{^use ExtUtils::MakeMaker 7\.26;$}m);
    like($mf, qr{^os_unsupported if \$\^O eq "MSWin32";$}m);
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
        module_maker => "ExtUtilsMakeMaker",
        unsupported => { os => [qw/MSWin32/] },
    });
    git_init_add_commit();
    Minilla::Project->new()->regenerate_files();
    git_init_add_commit();
    $code->();
}
