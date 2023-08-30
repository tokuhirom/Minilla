use strict;
use warnings;
use utf8;
use Test::More;
use Test::Requires 'Software::License';
use lib "t/lib";
use Util;
use File::Temp qw(tempdir);
use File::pushd;

use Minilla::CLI::New;
use Minilla::CLI;

subtest 'Specify license' => sub {
    my $guard = pushd(tempdir(CLEANUP => 1));
    Minilla::CLI::New->run('Acme::Speciality', '--username' => 'foo', '--email' => 'bar', '--license' => 'MIT');

    open my $fh, "Acme-Speciality/README.md";
    chomp (my $got = do { local $/; <$fh> });
    like $got, qr{MIT.+License};
};

done_testing;

