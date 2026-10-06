use strict;
use warnings;
use utf8;
use Test::More;

use lib "t/lib";
use Util;
use Archive::Tar;
use CPAN::Meta;
use Digest::SHA qw(sha256_hex);
use JSON;
use Test::Output qw(stdout_from);

use Minilla::CLI::Dist;
use Minilla::CLI;
use Minilla::Profile::Default;
use Minilla::Project;

my $guard = pushd(tempdir(CLEANUP => 1));

my $profile = Minilla::Profile::Default->new(
    author  => 'tokuhirom',
    dist    => 'Acme-Foo',
    path    => 'Acme/Foo.pm',
    suffix  => 'Foo',
    module  => 'Acme::Foo',
    version => '0.01',
    email   => 'tokuhirom@example.com',
);
$profile->generate();
write_minil_toml({
    name           => 'Acme-Foo',
    manage_changes => 0,
});

git_init();
git_config(qw(user.name tokuhirom));
git_config(qw(user.email tokuhirom@example.com));
git_add('.');
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

local $ENV{SOURCE_DATE_EPOCH} = 1700000000;
my $stdout = stdout_from(sub {
    Minilla::CLI->run('--no-auto-install', 'dist', '--skip-prepare', '--no-test');
});
is_deeply(
    decode_json($stdout),
    { dist => 'Acme-Foo-0.01.tar.gz' },
    'minil dist --skip-prepare logs the relative archive path',
);
my $first_dist = slurp_raw('Acme-Foo-0.01.tar.gz');

chmod(0777, 'Build.PL') or die "chmod: $!";
chmod(0600, 'README.md') or die "chmod: $!";
utime(1800000000, 1800000000, 'Build.PL', 'README.md');
Minilla::CLI::Dist->run('--skip-prepare', '--no-test');
my $second_dist = slurp_raw('Acme-Foo-0.01.tar.gz');

is(
    sha256_hex($second_dist),
    sha256_hex($first_dist),
    'minil dist --skip-prepare creates a reproducible tarball',
);

my $tar = Archive::Tar->new('Acme-Foo-0.01.tar.gz');
is(
    $tar->get_content('Acme-Foo-0.01/Build.PL'),
    $build_pl,
    'keeps the prepared Build.PL',
);
is(
    $tar->get_content('Acme-Foo-0.01/META.json'),
    $meta_json,
    'keeps the prepared META.json',
);
is(
    $tar->get_content('Acme-Foo-0.01/README.md'),
    $readme,
    'keeps the prepared README.md',
);
ok(
    $tar->contains_file('Acme-Foo-0.01/META.yml'),
    'generates META.yml for packaging',
);
is(
    CPAN::Meta->load_yaml_string(
        $tar->get_content('Acme-Foo-0.01/META.yml'),
        { lazy_validation => 0 },
    )->abstract,
    'Prepared abstract',
    'generates META.yml from the prepared META.json',
);
ok(
    $tar->contains_file('Acme-Foo-0.01/MANIFEST'),
    'generates MANIFEST for packaging',
);

done_testing;
