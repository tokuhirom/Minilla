use strict;
use warnings;
use utf8;
use Test::More;
use t::Util;

package Minilla::Profile::EUMM;
use parent qw(Minilla::Profile::Default);

use Test::More;

plan skip_all => "No git configuration" unless `git config user.email` =~ /\@/;

use File::Temp qw(tempdir);
use File::pushd;
use Data::Section::Simple qw(get_data_section);
use File::Basename qw(dirname);
use File::Path qw(mkpath);

use Minilla::Util qw(spew cmd slurp);
use Minilla::Migrate;
use Minilla::Git;

subtest 'Removing committed README' => sub {
    my $guard = pushd(tempdir());

    my $profile = Minilla::Profile::EUMM->new(
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
    $profile->render('Makefile.PL');
    $profile->render('MANIFEST');
    unlink 'Build.PL';
    unlink 'META.json';
    unlink 'cpanfile';

    git_init();
    git_add();
    git_commit('-m', 'initial import');

    Minilla::Migrate->new->run();

    ok -f 'META.json';
};

done_testing;

__DATA__

@@ minil.toml
name = "Acme-Foo"

@@ MANIFEST
Makefile.PL
minil.toml
lib/Acme/Foo.pm
cpanfile

@@ Makefile.PL
require 5.008001;
use strict;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME => 'Acme::Foo',
    VERSION_FROM => 'lib/Acme/Foo.pm',
    ABSTRACT => 'Acme style messages',
    AUTHOR => 'Ghha',
    LICENSE => "perl",
    MIN_PERL_VERSION => 5.008001,
    PREREQ_PM => {
    },
);
