use strict;
use warnings;
use utf8;
use Test::More;

use lib "t/lib";
use Util;
use Archive::Tar;

use Minilla::Profile::Default;
use Minilla::Project;

subtest 'configuration' => sub {
    my $guard = pushd(tempdir(CLEANUP => 1));

    is(Minilla::Project->new(dir => '.')->manage_changes, 1, 'enabled by default');

    spew('minil.toml', "manage_changes = false\n");
    is(Minilla::Project->new(dir => '.')->manage_changes, 0, 'can be disabled');

    spew('minil.toml', "manage_changes = true\n");
    is(Minilla::Project->new(dir => '.')->manage_changes, 1, 'can be enabled explicitly');
};

subtest 'distribution without Changes' => sub {
    my $guard = pushd(tempdir(CLEANUP => 1));

    my $profile = Minilla::Profile::Default->new(
        author => 'tokuhirom',
        dist => 'Acme-Foo',
        path => 'Acme/Foo.pm',
        suffix => 'Foo',
        module => 'Acme::Foo',
        version => '0.01',
        email => 'tokuhirom@example.com',
    );
    $profile->generate();
    spew('minil.toml', qq{name = "Acme-Foo"\nmanage_changes = false\n});
    unlink 'Changes' or die "Cannot remove Changes: $!";
    spew_raw('CHANGELOG.md', "# Changelog\n\nMaintained independently.\n");

    git_init();
    git_config(qw(user.name tokuhirom));
    git_config(qw(user.email tokuhirom@example.com));
    git_add('.');
    Minilla::Project->new()->regenerate_files();
    git_add('.');
    git_commit('-m', 'initial import');

    my $dist = Minilla::Project->new()->work_dir->dist;
    my $tar = Archive::Tar->new($dist);

    ok(!$tar->contains_file('Acme-Foo-0.01/Changes'), 'does not require Changes');
    is(
        $tar->get_content('Acme-Foo-0.01/CHANGELOG.md'),
        "# Changelog\n\nMaintained independently.\n",
        'includes an independently maintained changelog unchanged',
    );
};

subtest 'distribution with independently maintained Changes' => sub {
    my $guard = pushd(tempdir(CLEANUP => 1));

    my $profile = Minilla::Profile::Default->new(
        author => 'tokuhirom',
        dist => 'Acme-Foo',
        path => 'Acme/Foo.pm',
        suffix => 'Foo',
        module => 'Acme::Foo',
        version => '0.01',
        email => 'tokuhirom@example.com',
    );
    $profile->generate();
    spew('minil.toml', qq{name = "Acme-Foo"\nmanage_changes = false\n});
    spew_raw('Changes', "Release history maintained without a NEXT marker.\n");

    git_init();
    git_config(qw(user.name tokuhirom));
    git_config(qw(user.email tokuhirom@example.com));
    git_add('.');
    Minilla::Project->new()->regenerate_files();
    git_add('.');
    git_commit('-m', 'initial import');

    my $dist = Minilla::Project->new()->work_dir->dist;
    my $tar = Archive::Tar->new($dist);

    is(
        $tar->get_content('Acme-Foo-0.01/Changes'),
        "Release history maintained without a NEXT marker.\n",
        'includes independently maintained Changes unchanged',
    );
};

done_testing;
