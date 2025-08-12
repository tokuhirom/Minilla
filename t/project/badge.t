use strict;
use warnings;
use utf8;
use Test::More;
use lib "t/lib";
use Util;
use File::Temp qw(tempdir);
use File::pushd;
use File::Spec::Functions qw(catdir);
use Minilla::Profile::Default;
use Minilla::Project;

subtest 'Badge' => sub {
    my $guard = pushd(tempdir(CLEANUP => 1));

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

    # Add remote information
    {
        open my $fh, '>>', catdir('.git', 'config');
        print $fh <<'...';
[remote "origin"]
    fetch = +refs/heads/*:refs/remotes/origin/*
    url = git@github.com:tokuhirom/Minilla.git
...
    }

    subtest 'Badges exist' => sub {
        write_minil_toml({
            name   => 'Acme-Foo',
            badges => ['travis', 'travis-ci.com', 'circleci', 'appveyor', 'coveralls', 'gitter', 'codecov', 'metacpan', 'github-actions'],
        });
        $project->regenerate_files;

        open my $fh, '<', 'README.md';
        ok chomp (my $got = <$fh>);

        my $badge_markdowns = [
            "[![Build Status](https://travis-ci.org/tokuhirom/Minilla.svg?branch=master)](https://travis-ci.org/tokuhirom/Minilla)",
            "[![Build Status](https://travis-ci.com/tokuhirom/Minilla.svg?branch=master)](https://travis-ci.com/tokuhirom/Minilla)",
            "[![Build Status](https://circleci.com/gh/tokuhirom/Minilla.svg)](https://circleci.com/gh/tokuhirom/Minilla)",
            "[![Build Status](https://img.shields.io/appveyor/ci/tokuhirom/Minilla/master.svg?logo=appveyor)](https://ci.appveyor.com/project/tokuhirom/Minilla/branch/master)",
            "[![Coverage Status](https://img.shields.io/coveralls/tokuhirom/Minilla/master.svg?style=flat)](https://coveralls.io/r/tokuhirom/Minilla?branch=master)",
            "[![Gitter chat](https://badges.gitter.im/tokuhirom/Minilla.png)](https://gitter.im/tokuhirom/Minilla)",
            "[![Coverage Status](http://codecov.io/github/tokuhirom/Minilla/coverage.svg?branch=master)](https://codecov.io/github/tokuhirom/Minilla?branch=master)",
            "[![MetaCPAN Release](https://badge.fury.io/pl/Acme-Foo.svg)](https://metacpan.org/release/Acme-Foo)",
            "[![Actions Status](https://github.com/tokuhirom/Minilla/actions/workflows/test.yml/badge.svg?branch=master)](https://github.com/tokuhirom/Minilla/actions?workflow=test)",
        ];
        my $expected = join(' ', @$badge_markdowns);
        is $got, $expected;
    };

    subtest 'Badges with release branch' => sub {
        write_minil_toml({
            name   => 'Acme-Foo',
            badges => ['travis', 'travis-ci.com', 'appveyor', 'coveralls', 'codecov'],
            release => {
                branch => 'main',
            },
        });
        $project->clear_release_branch;
        $project->regenerate_files;

        open my $fh, '<', 'README.md';
        ok chomp (my $got = <$fh>);

        my $badge_markdowns = [
            "[![Build Status](https://travis-ci.org/tokuhirom/Minilla.svg?branch=main)](https://travis-ci.org/tokuhirom/Minilla)",
            "[![Build Status](https://travis-ci.com/tokuhirom/Minilla.svg?branch=main)](https://travis-ci.com/tokuhirom/Minilla)",
            "[![Build Status](https://img.shields.io/appveyor/ci/tokuhirom/Minilla/main.svg?logo=appveyor)](https://ci.appveyor.com/project/tokuhirom/Minilla/branch/main)",
            "[![Coverage Status](https://img.shields.io/coveralls/tokuhirom/Minilla/main.svg?style=flat)](https://coveralls.io/r/tokuhirom/Minilla?branch=main)",
            "[![Coverage Status](http://codecov.io/github/tokuhirom/Minilla/coverage.svg?branch=main)](https://codecov.io/github/tokuhirom/Minilla?branch=main)",
        ];
        my $expected = join(' ', @$badge_markdowns);
        is $got, $expected;

        $project->clear_release_branch;
    };

    subtest 'Badges do not exist' => sub {
        write_minil_toml('Acme-Foo');
        $project->regenerate_files;

        open my $fh, '<', 'README.md';
        ok chomp (my $got = <$fh>);
        is $got, "# NAME";
    };

    subtest 'Badges argument is illegal' => sub {
        write_minil_toml({
            name   => 'Acme-Foo',
            badges => 'I AM NOT ARRAY!',
        });
        $project->regenerate_files;

        open my $fh, '<', 'README.md';
        ok chomp (my $got = <$fh>);
        is $got, "# NAME";
    };

    # NOTE: When we add support for other providers, we can extend this test.
    subtest 'Badge additional parameters' => sub {
        write_minil_toml({
            name   => 'Acme-Foo',
            badges => ['travis?foo=bar&token=xxxyyyzzz'],
        });
        $project->regenerate_files;

        open my $fh, '<', 'README.md';
        ok chomp (my $got = <$fh>);

        my $badge_markdowns = [
            "[![Build Status](https://travis-ci.com/tokuhirom/Minilla.svg?branch=master&foo=bar&token=xxxyyyzzz)](https://travis-ci.com/tokuhirom/Minilla)",
        ];
        my $expected = join(' ', @$badge_markdowns);
        is $got, $expected;
    };

    subtest 'GitHub Actions workflow file / name' => sub {
        write_minil_toml({
            name   => 'Acme-Foo',
            badges => ['github-actions/foo.yml', 'github-actions/foo'],
        });
        $project->regenerate_files;

        open my $fh, '<', 'README.md';
        ok chomp (my $got = <$fh>);

        my $badge_markdowns = [
            "[![Actions Status](https://github.com/tokuhirom/Minilla/actions/workflows/foo.yml/badge.svg?branch=master)](https://github.com/tokuhirom/Minilla/actions?workflow=foo)",
            "[![Actions Status](https://github.com/tokuhirom/Minilla/actions/workflows/foo.yml/badge.svg?branch=master)](https://github.com/tokuhirom/Minilla/actions?workflow=foo)",
        ];
        my $expected = join(' ', @$badge_markdowns);
        is $got, $expected;
    };

    subtest 'AppVeyor repository rename' => sub {
        my $guard   = pushd( tempdir(CLEANUP => 1) );
        my $profile = Minilla::Profile::Default->new(
            dist    => 'Hashids',
            path    => 'Hashids.pm',
            module  => 'Hashids',
        );
        $profile->generate();
        git_init_add_commit();
        my $project = Minilla::Project->new();
        {
            open my $fh, '>>', catdir('.git', 'config');
            print $fh <<'...';
[remote "origin"]
    fetch = +refs/heads/*:refs/remotes/origin/*
    url = git@github.com:zakame/hashids.pm.git
...
        }

        {
            write_minil_toml(
                {   name   => 'Hashids',
                    badges => ['appveyor'],
                }
            );
            $project->regenerate_files;

            open my $fh, '<', 'README.md';
            ok chomp( my $got = <$fh> );

            is $got,
                "[![Build Status](https://img.shields.io/appveyor/ci/zakame/hashids-pm/master.svg?logo=appveyor)](https://ci.appveyor.com/project/zakame/hashids-pm/branch/master)";
        }

        subtest 'AppVeyor in badge list' => sub {
            write_minil_toml(
                {   name   => 'Hashids',
                    badges => [ 'appveyor', 'travis' ],
                }
            );
            $project->regenerate_files;

            open my $fh, '<', 'README.md';
            ok chomp( my $got = <$fh> );

            my $expected = "[![Build Status](https://img.shields.io/appveyor/ci/zakame/hashids-pm/master.svg?logo=appveyor)](https://ci.appveyor.com/project/zakame/hashids-pm/branch/master) [![Build Status](https://travis-ci.org/zakame/hashids.pm.svg?branch=master)](https://travis-ci.org/zakame/hashids.pm)";
            is $got, $expected;
        };
    };
};

done_testing;
