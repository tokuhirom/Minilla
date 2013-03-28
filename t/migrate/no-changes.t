use strict;
use warnings;
use utf8;
use Test::More;

use strict;
use warnings;
use utf8;

package Minilla::Profile::NoChanges;
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
    unlink 'Changes';

    git_init();
    git_add();
    git_commit('-m', 'initial import');

    Minilla::Migrate->new->run();

    like(slurp('Changes'), qr!\{\{\$NEXT\}\}!);
};

done_testing;

__DATA__

@@ minil.toml
name = "Acme-Foo"


