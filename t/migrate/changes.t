use strict;
use warnings;
use utf8;
use Test::More;
use t::Util;

package Minilla::Profile::Changes;
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

subtest 'Insert {{$NEXT}}' => sub {
    my $guard = pushd(tempdir());

    my $profile = Minilla::Profile::Changes->new(
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
    $profile->render('Changes');

    git_init();
    git_add();
    git_commit('-m', 'initial import');

    Minilla::Migrate->new->run();

    like(slurp('Changes'), qr!\{\{\$NEXT\}\}!);
};

subtest 'Do not {{$NEXT}} twice' => sub {
    my $guard = pushd(tempdir());

    my $profile = Minilla::Profile::Changes->new(
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
    $profile->render('Changes');

    git_init();
    git_add();
    git_commit('-m', 'initial import');

    Minilla::Migrate->new->run();
    Minilla::Migrate->new->run();

    my $content = slurp('Changes');
    my $n;
    $content =~ s!\{\{\$NEXT\}\}!$n++!ge;
    is($n, 1);
};

done_testing;

__DATA__

@@ minil.toml
name = "Acme-Foo"

@@ Changes
Revision history for Perl extension Minilla

0.01 2013-02-02

    - foo

