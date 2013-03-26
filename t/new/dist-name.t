use strict;
use warnings;
use utf8;
use Test::More;
use File::Temp qw(tempdir);
use File::pushd;

use Minilla::CLI::New;
use Minilla::CLI;

subtest 'Acme::Speciality' => sub {
    my $guard = pushd(tempdir(CLEANUP => 1));
    Minilla::CLI::New->run('Acme::Speciality', '--username' => 'foo', '--email' => 'bar');
    ok -e 'Acme-Speciality/lib/Acme/Speciality.pm';
};

# `minil new` should allow Dist-Name style.
subtest 'Acme-Speciality' => sub {
    my $guard = pushd(tempdir(CLEANUP => 1));
    Minilla::CLI::New->run('Acme::Speciality', '--username' => 'foo', '--email' => 'bar');
    ok -e 'Acme-Speciality/lib/Acme/Speciality.pm';
};

done_testing;

