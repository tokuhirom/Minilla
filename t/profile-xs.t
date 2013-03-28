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
use Minilla::Project;

my $guard = pushd(tempdir(CLEANUP => 0));

Minilla::Profile::XS->new(
    dist => 'Acme-Foo',
    module => 'Acme::Foo',
    path => 'Acme/Foo.pm',
)->generate();
write_minil_toml('Acme::Foo');
git_init_add_commit();
Minilla::Project->new()->regenerate_files();
git_init_add_commit();

ok(-f 'Build.PL');
cmp_ok((-s 'Build.PL'), '>', 0);
ok(-f 'lib/Acme/Foo.pm');
like(slurp('lib/Acme/Foo.pm'), qr{XSLoader});
ok(-f '.travis.yml');
ok(-f 't/00_compile.t');
note(join(" ", git_ls_files()));
note slurp('.gitignore');
ok(0+(grep /ppport\.h/, git_ls_files()));

{
    my $project = Minilla::Project->new();
    my $work_dir = $project->work_dir;
    $work_dir->build;
    $work_dir->dist_test();
}

done_testing;

