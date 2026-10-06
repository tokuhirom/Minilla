use strict;
use warnings;
use utf8;
use Test::More;
use Test::Output;
use lib "t/lib";
use Util;
use Minilla::CLI::Clean;

my $guard = pushd(tempdir(CLEANUP => 1));

{
    write_minil_toml({
        name => 'Acme-Foo',
    });
    git_init_add_commit();

    mkdir 'Acme-Foo-0.01';
    mkdir 'Acme-Foo-1.00';

    output_is(
        sub { Minilla::CLI::Clean->run('-y') },
        '',
        "Would remove Acme-Foo-0.01\nWould remove Acme-Foo-1.00\n",
        'clean status is written to standard error',
    );

    ok(!-d 'Acme-Foo-0.01/' && !-d 'Acme-Foo-1.00', 'Cleaned built directories');
}

done_testing;
