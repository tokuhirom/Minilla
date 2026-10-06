use strict;
use warnings;
use utf8;
use Test::More;
use Test::Output;
use Test::Requires 'Version::Next', 'CPAN::Uploader';

use Archive::Tar;
use JSON;

use lib "t/lib";
use Util;
use Minilla;
use Minilla::CLI::Release;
use Minilla::Profile::ModuleBuild;
use Minilla::Project;
use Minilla::Release::BumpVersion;

my $repo = tempdir(CLEANUP => 1);
{
    my $guard = pushd($repo);
    cmd('git', 'init', '--bare');
}

my $guard = pushd(tempdir(CLEANUP => 1));

Minilla::Profile::ModuleBuild->new(
    author  => 'hoge',
    dist    => 'Acme-Foo',
    module  => 'Acme::Foo',
    path    => 'Acme/Foo.pm',
    version => '0.01',
)->generate();
write_minil_toml('Acme-Foo');
git_init();
git_config(qw(user.name tokuhirom));
git_config(qw(user.email tokuhirom@example.com));
Minilla::Project->new()->regenerate_files();

my $build_pl = slurp('Build.PL') . "\n# prepared Build.PL\n";
my $meta = decode_json(slurp('META.json'));
$meta->{abstract} = 'Prepared abstract';
$meta->{x_prepared} = 'kept';
my $meta_json = JSON->new->canonical->pretty->encode($meta);
my $readme = "# Prepared README\n";
spew_raw('Build.PL', $build_pl);
spew_raw('META.json', $meta_json);
spew_raw('README.md', $readme);

git_add('.');
git_commit('-m', 'prepared release');
git_remote('add', 'origin', "file://$repo");

{
    local $Minilla::DEBUG = 1;
    local $ENV{PERL_MM_USE_DEFAULT} = 1;
    local $ENV{PERL_MINILLA_SKIP_CHECK_CHANGE_LOG} = 1;
    local $ENV{FAKE_RELEASE} = 1;
    no warnings 'redefine';
    local *Minilla::Release::BumpVersion::prompt = sub {
        die "version prompt should not be called\n";
    };
    Minilla::CLI::Release->run('--skip-prepare', '--no-test');
}

is(slurp('Build.PL'), $build_pl, 'keeps the prepared Build.PL');
is(slurp('META.json'), $meta_json, 'keeps the prepared META.json');
is(slurp('README.md'), $readme, 'keeps the prepared README.md');

my $build_dir = $^O eq 'MSWin32' ? '_build' : '.build';
my ($tarball) = glob("$build_dir/*/Acme-Foo-0.01.tar.gz");
ok($tarball, 'created a release tarball');

my $tar = Archive::Tar->new($tarball);
is(
    $tar->get_content('Acme-Foo-0.01/Build.PL'),
    $build_pl,
    'packages the prepared Build.PL',
);
is(
    $tar->get_content('Acme-Foo-0.01/README.md'),
    $readme,
    'packages the prepared README.md',
);
my $dist_meta = CPAN::Meta->load_json_string(
    $tar->get_content('Acme-Foo-0.01/META.json'),
    { lazy_validation => 0 },
);
is($dist_meta->release_status, 'stable', 'finalizes the packaged release status');
my $provided_file = $dist_meta->provides->{'Acme::Foo'}{file};
$provided_file =~ s!\\!/!g;
is(
    $provided_file,
    'lib/Acme/Foo.pm',
    'finalizes packaged provides',
);
is($dist_meta->abstract, 'Prepared abstract', 'keeps prepared standard metadata');
is($dist_meta->custom('x_prepared'), 'kept', 'keeps prepared custom metadata');

{
    local $ENV{PERL_MINILLA_SKIP_CHECK_CHANGE_LOG} = 1;
    local $ENV{FAKE_RELEASE} = 1;
    my $error;
    stderr_like(
        sub {
            eval {
                Minilla::CLI::Release->run('--skip-prepare', '--no-test');
            };
            $error = $@;
        },
        qr/version '0\.01' is already tagged/,
        'rejects an already tagged prepared version',
    );
    isa_ok($error, 'Minilla::Error::CommandExit');
}

done_testing;
