use strict;
use warnings;
use utf8;
use Test::More;
use t::Util;

use Minilla::Profile::Default;
use Minilla::Project;
use Minilla::Git;

subtest 'develop deps' => sub {
    my $guard = pushd(tempdir());

    my $profile = Minilla::Profile::Default->new(
        author => 'tokuhirom',
        dist => 'Acme-Foo',
        path => 'Acme/Foo.pm',
        suffix => 'Foo',
        module => 'Acme::Foo',
        version => '0.01',
        email => 'tokuhirom@example.com',
    );
    $profile->generate();
    write_minil_toml('Acme-Foo');

    git_init();
    git_add('.');
    git_config(qw(user.name tokuhirom));
    git_config(qw(user.email tokuhirom@example.com));
    git_commit('-m', 'initial import');

    git_config(qw(user.name Foo));
    git_config(qw(user.email foo@example.com));
    git_commit('--allow-empty', '-m', 'foo');
    git_config(qw(user.name Bar));
    git_config(qw(user.email bar@example.com));
    git_commit('--allow-empty', '-m', 'bar');
    git_commit('--allow-empty', '-m', 'bar2');

    is_deeply(
        Minilla::Project->new()->contributors,
        ['Foo <foo@example.com>',
        'Bar <bar@example.com>'],
    );
};

done_testing;

