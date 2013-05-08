use strict;
use warnings;
use utf8;
use Test::More;
use t::Util;
use File::Temp qw(tempdir);
use File::pushd;

use Minilla::Util qw(spew);
use Minilla::FileGatherer;
use Minilla::Git;

can_ok('Minilla::FileGatherer', 'new');

subtest 'FileGatherer' => sub {
    my $guard = init();

    subtest 'normal' => sub {
        my @files = Minilla::FileGatherer->new(
            exclude_match => ['^local/'],
        )->gather_files('.');

        is(join(',', sort @files), 'META.json,README,foo');
    };

    subtest include_dotfiles => sub {
        my @files = Minilla::FileGatherer->new(
            exclude_match => ['^local/'],
            include_dotfiles => 1,
        )->gather_files('.');

        is(join(',', sort @files), '.dot/dot,.gitignore,META.json,README,foo,xtra/.dot,xtra/.dotdir/dot');
    };

    subtest 'MANIFEST.SKIP' => sub {
        spew('MANIFEST.SKIP', q{^foo$});
        git_init_add_commit();

        my @files = Minilla::FileGatherer->new(
            exclude_match => ['^local/'],
        )->gather_files('.');

        is(join(',', sort @files), 'MANIFEST.SKIP,META.json,README');
    };
};

done_testing;

sub init {
    my $guard = pushd(tempdir());

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
    git_commit('-m', 'foo');

    $guard;
}
