use strict;
use warnings;
use utf8;
use Test::More;
use t::Util;
use Minilla::CLI::Clean;

my $guard = pushd(tempdir());

{
    write_minil_toml({
        name => 'Acme-Foo',
    });
    git_init_add_commit();

    mkdir 'Acme-Foo-0.01';
    mkdir 'Acme-Foo-1.00';

    Minilla::CLI::Clean->run('-y');

    ok(!-d 'Acme-Foo-0.01/' && !-d 'Acme-Foo-1.00', 'Cleaned built directories');
}

done_testing;
