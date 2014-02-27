use strict;
use warnings;
use utf8;
use Test::More;
use t::Util;
use File::Temp qw(tempdir);
use File::pushd;
use File::Spec::Functions qw(catdir);
use Minilla::Profile::Default;
use Minilla::Project;

subtest 'ReleaseTest.MinimumVersion' => sub {
    subtest 'no minimumversion' => sub {
        my $guard = pushd(tempdir());

        my $project = create_project();

        spew('minil.toml', <<'...');
name = "Acme-Foo"
[ReleaseTest]
MinimumVersion = false
...
        my $workdir = $project->work_dir();
        $workdir->build;

        {
            my $guard = pushd($workdir->dir);
            ok -f 'xt/minilla/pod.t', 'Exists xt/minilla/minimum_version.t';
            ok !-f 'xt/minilla/minimum_version.t';
        }
    };

    subtest 'normal case' => sub {
        my $guard = pushd(tempdir());

        my $project = create_project();

        write_minil_toml('Acme-Foo');

        my $workdir = $project->work_dir();
        $workdir->build;

        {
            my $guard = pushd($workdir->dir);
            ok -f 'xt/minilla/pod.t';
            ok -f 'xt/minilla/minimum_version.t';
        }
    };
};

done_testing;

sub create_project {
    my $profile = Minilla::Profile::Default->new(
        author => 'foo',
        dist => 'Acme-Foo',
        path => 'Acme/Foo.pm',
        suffix => 'Foo',
        module => 'Acme::Foo',
        version => '0.01',
        email => 'foo@example.com',
    );
    $profile->generate();
    git_init_add_commit();
    my $project = Minilla::Project->new();
    return $project;
}
