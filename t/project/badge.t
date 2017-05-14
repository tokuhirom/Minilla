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
    my $guard = pushd(tempdir());

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
            badges => ['travis', 'circleci', 'appveyor', 'coveralls', 'gitter', 'codecov', 'metacpan'],
        });
        $project->regenerate_files;

        open my $fh, '<', 'README.md';
        ok chomp (my $got = <$fh>);

        my $badge_markdowns = [
            "[![Build Status](https://travis-ci.org/tokuhirom/Minilla.svg?branch=master)](https://travis-ci.org/tokuhirom/Minilla)",
            "[![Build Status](https://circleci.com/gh/tokuhirom/Minilla.svg)](https://circleci.com/gh/tokuhirom/Minilla)",
            "[![Build Status](https://img.shields.io/appveyor/ci/tokuhirom/Minilla/master.svg)](https://ci.appveyor.com/project/tokuhirom/Minilla/branch/master)",
            "[![Coverage Status](https://img.shields.io/coveralls/tokuhirom/Minilla/master.svg?style=flat)](https://coveralls.io/r/tokuhirom/Minilla?branch=master)",
            "[![Gitter chat](https://badges.gitter.im/tokuhirom/Minilla.png)](https://gitter.im/tokuhirom/Minilla)",
            "[![Coverage Status](http://codecov.io/github/tokuhirom/Minilla/coverage.svg?branch=master)](https://codecov.io/github/tokuhirom/Minilla?branch=master)",
            "[![MetaCPAN Release](https://badge.fury.io/pl/Acme-Foo.svg)](https://metacpan.org/release/Acme-Foo)"
        ];
        my $expected = join(' ', @$badge_markdowns);
        is $got, $expected;
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
};

done_testing;
