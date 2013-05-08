use strict;
use warnings;
use utf8;
use Test::More;
use t::Util;

package Minilla::Profile::NoPod;
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

subtest 'No Changes' => sub {
    my $guard = pushd(tempdir());

    my $profile = __PACKAGE__->new(
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
    $profile->render('lib/Acme/Foo.pm');

    git_init();
    git_add();
    git_commit('-m', 'initial import');

    eval {
        Minilla::Migrate->new->run();
    };
    my $e = $@;
    isa_ok($e, 'Minilla::Error::CommandExit');
    like($e->body, qr/Cannot retrieve 'abstract'/);
};

done_testing;

__DATA__

@@ minil.toml
name = "Acme-Foo"

@@ lib/Acme/Foo.pm
package Acme::Foo;
1;
