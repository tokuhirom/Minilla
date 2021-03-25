use strict;
use warnings;
use utf8;
use Test::More;
use Test::Requires 'Version::Next', 'CPAN::Uploader';
use lib "t/lib";
use Util;
use Minilla::Profile::ModuleBuild;
use Minilla::CLI::Release;

subtest 'wrong release branch' => sub {
    my $RELEASE_BRANCH = 'GREAT_RELEASE_BRANCH';

    my $repo = tempdir(CLEANUP => 1);
    {
        my $guard = pushd($repo);
        cmd('git', 'init', '--bare');
    }

    my $guard = pushd(tempdir(CLEANUP => 1));


    Minilla::Profile::ModuleBuild->new(
        author => 'hoge',
        dist => 'Acme-Foo',
        module => 'Acme::Foo',
        path => 'Acme/Foo.pm',
        version => '0.01',
    )->generate();
    write_minil_toml({
        name => 'Acme-Foo',
        release => {
            branch => $RELEASE_BRANCH,
        },
    });
    git_init_add_commit();
    git_remote('add', 'origin', "file://$repo");

    {
        local $ENV{PERL_MM_USE_DEFAULT} = 1;
        local $ENV{PERL_MINILLA_SKIP_CHECK_CHANGE_LOG} = 1;
        local $ENV{FAKE_RELEASE} = 1;
        eval {
            Minilla::CLI::Release->run();
        };
        my $e = $@;
        like $e, qr!Release branch must be $RELEASE_BRANCH!;
    }
};

subtest 'correct release branch' => sub {
    my $RELEASE_BRANCH = 'main';

    my $repo = tempdir(CLEANUP => 1);
    {
        my $guard = pushd($repo);
        cmd('git', 'init', '--bare');
    }

    my $guard = pushd(tempdir(CLEANUP => 1));

    Minilla::Profile::ModuleBuild->new(
        author => 'hoge',
        dist => 'Acme-Foo',
        module => 'Acme::Foo',
        path => 'Acme/Foo.pm',
        version => '0.01',
    )->generate();
    write_minil_toml({
        name => 'Acme-Foo',
        release => {
            branch => $RELEASE_BRANCH,
        },
    });
    git_init_add_commit();
    git_remote('add', 'origin', "file://$repo");

    cmd('git', 'branch','-M', $RELEASE_BRANCH);

    {
        local $ENV{PERL_MM_USE_DEFAULT} = 1;
        local $ENV{PERL_MINILLA_SKIP_CHECK_CHANGE_LOG} = 1;
        local $ENV{FAKE_RELEASE} = 1;
        Minilla::CLI::Release->run();
        pass 'released.';
    }
};

done_testing;

