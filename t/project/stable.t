use strict;
use warnings;
use utf8;
use Test::More;
use lib "t/lib";
use Util;

use CPAN::Meta;

use Minilla::Profile::Default;
use Minilla::Project;
use Minilla::Git;
use CPAN::Meta;
use File::Spec;

use Minilla::CLI::Build;

subtest 'stable' => sub {
    my $guard = pushd(tempdir());

    my $profile = Minilla::Profile::Default->new(
        author => 'Tokuhiro Matsuno',
        dist => 'Acme-Foo',
        path => 'Acme/Foo.pm',
        suffix => 'Foo',
        module => 'Acme::Foo',
        version => '3.008008',
        email => 'tokuhirom@example.com',
    );
    $profile->generate();
    write_minil_toml('Acme-Foo');

    git_init_add_commit();

    my $project = Minilla::Project->new();
    my $work_dir = $project->work_dir();
    $work_dir->build;

    my $metapath = File::Spec->catfile($work_dir->dir, 'META.json');
    ok -f $metapath;
    my $meta = CPAN::Meta->load_file($metapath);
    is($meta->{release_status}, 'stable');
};

subtest 'stable_with_cli' => sub {
    my $guard = pushd(tempdir());

    my $profile = Minilla::Profile::Default->new(
        author => 'Tokuhiro Matsuno',
        dist => 'Acme-Foo',
        path => 'Acme/Foo.pm',
        suffix => 'Foo',
        module => 'Acme::Foo',
        version => '3.008008',
        email => 'tokuhirom@example.com',
    );
    $profile->generate();
    write_minil_toml('Acme-Foo');

    git_init_add_commit();

    my $project = Minilla::Project->new();

    Minilla::CLI::Build->run();

    my $metapath = File::Spec->catfile($guard, 'META.json');
    ok -f $metapath;
    my $meta = CPAN::Meta->load_file($metapath);
    is($meta->{release_status}, 'stable');
};

done_testing;

