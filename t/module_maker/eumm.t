use strict;
use warnings;
use utf8;
use Test::More;
use t::Util;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use File::Temp qw(tempdir);
use File::pushd;

use Minilla::CLI::New;
use Minilla::CLI;
use Minilla::Util;
use Config;

subtest 'Acme::Speciality' => sub {
    my $guard = pushd(tempdir(CLEANUP => 1));
    Minilla::CLI::New->run(
        'Acme::Speciality',
        '--username' => 'foo',
        '--email'    => 'bar',
        '--profile', 'ExtUtilsMakeMaker'
    );
    ok -e 'Acme-Speciality/lib/Acme/Speciality.pm';

    subtest 'minil.toml was generated', sub {
        ok -e 'Acme-Speciality/minil.toml';
    };

    subtest '"module_maker" was specified', sub {
        my $got = slurp("Acme-Speciality/minil.toml");
        like $got, qr{module_maker="ExtUtilsMakeMaker"};
    };

    subtest 'Makefile.PL uses EUMM', sub {
        ok !-f 'Acme-Speciality/Build.PL';
        ok -f 'Acme-Speciality/Makefile.PL';
        my $got = slurp("Acme-Speciality/Makefile.PL");
        like $got, qr{use ExtUtils::MakeMaker};
        note $got;
    };

    {
        my $guard2 = pushd("Acme-Speciality");

        my $project = Minilla::Project->new(dir => ".");
        isa_ok $project->module_maker(), 'Minilla::ModuleMaker::ExtUtilsMakeMaker';
        $project->regenerate_files;

        ok -f 'Makefile.PL';
        is(system($^X, 'Makefile.PL'), 0);
        is(system($Config{'make'}), 0);
        note `tree`;
    }
};

done_testing;

