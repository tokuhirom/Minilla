use strict;
use warnings;
use utf8;

package Minilla::Profile::Tempfiles;
use parent qw(Minilla::Profile::Default);

use Test::More;

plan skip_all => "No git configuration" unless `git config user.email` =~ /\@/;

use File::Temp qw(tempdir);
use File::pushd;
use Data::Section::Simple qw(get_data_section);
use File::Basename qw(dirname);
use File::Path qw(mkpath);

use Minilla::Util qw(spew cmd);
use Minilla::Migrate;
use Minilla::Git;

subtest 'Removing committed README' => sub {
    my $guard = pushd(tempdir());

    my $profile = Minilla::Profile::Tempfiles->new(
        author => 'foo',
        dist => 'Acme-Foo',
        path => 'Acme/Foo.pm',
        suffix => 'Foo',
        module => 'Acme::Foo',
        version => '0.01',
        email => 'foo@example.com',
    );
    $profile->generate();
    $profile->render('minil.toml');
    $profile->render('README');

    git_init();
    git_add();
    git_commit('-m', 'initial import');

    Minilla::Migrate->new->run();

    ok(!-f 'README');
};

subtest 'Removing ignored README' => sub {
    my $guard = pushd(tempdir());

    my $profile = Minilla::Profile::Tempfiles->new(
        author => 'foo',
        dist => 'Acme-Foo',
        path => 'Acme/Foo.pm',
        suffix => 'Foo',
        module => 'Acme::Foo',
        version => '0.01',
        email => 'foo@example.com',
    );
    $profile->generate();
    $profile->render('minil.toml');
    $profile->render('README');

    my $gi = Minilla::Gitignore->load('.gitignore');
    $gi->add('/README');
    $gi->save('.gitignore');

    git_init();
    git_add();
    git_commit('-m', 'initial import');

    Minilla::Migrate->new->run();

    ok(!-f 'README');
};

done_testing;

__DATA__

@@ minil.toml
name = "Acme-Foo"

@@ README
AAA
