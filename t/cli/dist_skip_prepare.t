use strict;
use warnings;
use utf8;
use Test::More;

use lib "t/lib";
use Util;
use Archive::Tar;
use JSON;

use Minilla::CLI::Dist;
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
write_minil_toml('Acme-Foo');

git_init();
git_config(qw(user.name tokuhirom));
git_config(qw(user.email tokuhirom@example.com));
git_add('.');
Minilla::Project->new()->regenerate_files();

my $build_pl = slurp('Build.PL') . "\n# prepared Build.PL\n";
my $meta = decode_json(slurp('META.json'));
$meta->{x_prepared} = 'kept';
my $meta_json = JSON->new->canonical->pretty->encode($meta);
my $readme = "# Prepared README\n";
spew('Build.PL', $build_pl);
spew('META.json', $meta_json);
spew('README.md', $readme);
git_add('.');
git_commit('-m', 'prepared release');

Minilla::CLI::Dist->run('--skip-prepare', '--no-test');

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
ok(
    $tar->contains_file('Acme-Foo-0.01/MANIFEST'),
    'generates MANIFEST for packaging',
);

done_testing;
