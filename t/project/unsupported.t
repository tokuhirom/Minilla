use strict;
use warnings;
use utf8;
use Test::More;
use lib "t/lib";
use Util;

use CPAN::Meta;

use Minilla::Profile::Default;
use Minilla::Project;
use Minilla::Git;
use CPAN::Meta;
use File::Spec;

subtest 'unsupported' => sub {
    my $guard = pushd(tempdir());

    my $profile = Minilla::Profile::Default->new(
        author => 'Tokuhiro Matsuno',
        dist => 'Acme-Foo',
        path => 'Acme/Foo.pm',
        suffix => 'Foo',
        module => 'Acme::Foo',
        version => '0.01',
        email => 'tokuhirom@example.com',
    );
    $profile->generate();
    write_minil_toml({
        name => 'Acme-Foo',
        unsupported => {
            os => [qw/MSWin32/],
        },
    });

    git_init_add_commit();

    my $project = Minilla::Project->new();
    is @{ $project->unsupported->os }, 1;
    is $project->unsupported->os->[0], 'MSWin32';
};

subtest 'empty unsupported' => sub {
    my $guard = pushd(tempdir());

    my $profile = Minilla::Profile::Default->new(
        author => 'Tokuhiro Matsuno',
        dist => 'Acme-Foo',
        path => 'Acme/Foo.pm',
        suffix => 'Foo',
        module => 'Acme::Foo',
        version => '0.01',
        email => 'tokuhirom@example.com',
    );
    $profile->generate();
    write_minil_toml('Acme-Foo');

    git_init_add_commit();

    my $project = Minilla::Project->new();
    is @{ $project->unsupported->os }, 0;
};

done_testing;

