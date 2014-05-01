use strict;
use warnings;
use utf8;
use Test::More;
use Test::Requires {'Module::Build::Tiny', 0.035};
use t::Util;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use File::Temp qw(tempdir);
use File::pushd;

use Minilla::CLI::New;
use Minilla::CLI;
use Minilla::Util;

subtest 'Acme::Speciality' => sub {
    my $guard = pushd(tempdir(CLEANUP => 1));
    Minilla::CLI::New->run('Acme::Speciality', '--username' => 'foo', '--email' => 'bar', '--profile', 'ModuleBuildTiny');
    ok -e 'Acme-Speciality/lib/Acme/Speciality.pm';

    subtest 'minil.toml was generated', sub {
        ok -e 'Acme-Speciality/minil.toml';
    };

    subtest '"module_maker" was specified', sub {
        my $got = slurp("Acme-Speciality/minil.toml");
        like $got, qr{module_maker="ModuleBuildTiny"};
    };

    subtest 'Build.PL uses M::B::Tiny', sub {
        my $got = slurp("Acme-Speciality/Build.PL");
        like $got, qr{use Module::Build::Tiny};
    };

    {
        my $guard2 = pushd("Acme-Speciality");

        my $project = Minilla::Project->new(dir => ".");
        isa_ok $project->module_maker(), 'Minilla::ModuleMaker::ModuleBuildTiny';
        $project->regenerate_files;

        ok -f 'Build.PL';
        is(system($^X, 'Build.PL'), 0);
        is(system($^X, './Build'), 0);
        system 'tree';
    }
};

done_testing;

