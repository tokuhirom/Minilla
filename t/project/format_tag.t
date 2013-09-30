use strict;
use warnings;
use utf8;
use Test::More;
use t::Util;

use Test::More;

use File::Temp qw(tempdir);
use File::pushd;
use File::Basename qw(dirname);
use File::Path qw(mkpath);
use Minilla::Profile::Default;
use Minilla::Project;
use CPAN::Meta::Validator;

subtest 'basic' => sub {
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
    spew('cpanfile', 'requires "Moose";');
    write_minil_toml('Acme-Foo');

    git_init_add_commit();

    is(Minilla::Project->new()->format_tag('1.0'), '1.0');
};

subtest 'customized' => sub {
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
    spew('cpanfile', 'requires "Moose";');
    write_minil_toml({
        name => 'Acme-Foo',
        'tag_format' => 'moris/%v',
    });

    git_init_add_commit();

    is(Minilla::Project->new()->format_tag('1.0'), 'moris/1.0');
};

done_testing;

