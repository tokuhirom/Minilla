use strict;
use warnings;
use utf8;
use Test::More;
use lib "t/lib";
use Util;
use File::Temp qw(tempdir);
use File::pushd;

use Minilla::Util qw(cmd spew);
use Minilla::FileGatherer;
use Minilla::Git;

can_ok('Minilla::FileGatherer', 'new');

subtest 'FileGatherer' => sub {
    my $guard = init();

    subtest 'normal' => sub {
        my @files = Minilla::FileGatherer->new(
            exclude_match => ['^local/'],
        )->gather_files('.');

        is(join(',', sort @files), 'META.json,README,foo,libbar/bar.c,libbar/libbar/bar.c,libbar/libfoo/foo.c,libfoo/foo.c,libfoo/libbar/bar.c,libfoo/libfoo/foo.c');
    };

    subtest include_dotfiles => sub {
        my @files = Minilla::FileGatherer->new(
            exclude_match => ['^local/'],
            include_dotfiles => 1,
        )->gather_files('.');

        is(join(',', sort @files), '.dot/dot,.gitignore,.gitmodules,META.json,README,foo,libbar/.gitmodules,libbar/bar.c,libbar/libbar/bar.c,libbar/libfoo/foo.c,libfoo/.gitmodules,libfoo/foo.c,libfoo/libbar/bar.c,libfoo/libfoo/foo.c,xtra/.dot,xtra/.dotdir/dot');
    };

    subtest 'MANIFEST.SKIP' => sub {
        spew('MANIFEST.SKIP', q{^foo$});
        git_init_add_commit();

        my @files = Minilla::FileGatherer->new(
            exclude_match => ['^local/'],
        )->gather_files('.');

        is(join(',', sort @files), 'MANIFEST.SKIP,META.json,README,libbar/bar.c,libbar/libbar/bar.c,libbar/libfoo/foo.c,libfoo/foo.c,libfoo/libbar/bar.c,libfoo/libfoo/foo.c');
    };
};

done_testing;

sub init {
    my $guard = pushd(tempdir(CLEANUP => 1));
    my %submodule_repos = map { $_ => create_deep_submodule_repo($_) } qw/foo bar/;

    mkdir 'local';
    mkdir '.dot';
    mkpath 'xtra/.dotdir';
    mkpath 'extlib/lib';
    spew('local/foo', '...');
    spew('extlib/lib/Foo.pm', '...');
    spew('.gitignore', '...');
    spew('README', 'rrr');
    spew('META.json', 'mmm');
    spew('foo', 'mmm');
    spew('.dot/dot', 'dot');
    spew('xtra/.dot', 'dot');
    spew('xtra/.dotdir/dot', '...');

    git_init();
    git_add('.');
    git_submodule_add("file://$submodule_repos{$_}", "lib$_") for keys %submodule_repos;
    cmd(qw(git submodule update --init --recursive));
    git_commit('-m', 'foo');

    $guard;
}

sub create_deep_submodule_repo {
    my $name = shift;

    my $dir = create_submodule_repo($name);
    my $guard = pushd($dir);

    my %submodule_repos = map { $_ => create_submodule_repo($_) } qw/foo bar/;

    git_add('.');
    git_submodule_add("file://$submodule_repos{$_}", "lib$_") for keys %submodule_repos;
    git_commit('-m', 'deep submodule');

    return $dir;
}

sub create_submodule_repo {
    my $name = shift;

    my $dir = tempdir(CLEANUP => 1);
    my $guard = pushd($dir);

    spew("$name.c", '...');
    git_init();
    git_add('.');
    git_commit('-m', 'submodule');

    return $dir;
}
