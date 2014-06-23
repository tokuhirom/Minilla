use strict;
use warnings;
use utf8;
use Test::More;
use t::Util;
use FindBin;
use lib "$FindBin::Bin/../../../lib";
use File::Temp qw(tempdir);
use File::pushd;

use Minilla::CLI;
use Minilla::CLI::New;
use Minilla::ReleaseTest;

my $original_write_release_tests = *Minilla::ReleaseTest::write_release_tests{CODE};
undef *Minilla::ReleaseTest::write_release_tests;
*Minilla::ReleaseTest::write_release_tests = sub {}; # Do nothing

my $minil = File::Spec->rel2abs('script/minil');

subtest 'dist test' => sub {
    my $guard = pushd(tempdir(CLEANUP => 1));

    Minilla::CLI::New->run('Acme::Speciality', '--username' => 'foo', '--email' => 'bar', '--profile', 'ExtUtilsMakeMaker');

    chdir 'Acme-Speciality';

    {
        mkdir 'xt';
        open my $fh, '>', 'xt/fail.t';
        print $fh <<'...';
use strict;
use warnings;
use Test::More;
ok 0; # Failure
done_testing;
...
        system 'git add .';
    }

    subtest 'run only t/*.t and pass all' => sub {
        is test_by(''), 0;
        is test_by('--automated'), 0;
        is test_by('--author'), 0;
    };

    subtest 'run t/*.t and xt/*.t and fail' => sub {
        isnt test_by('--release'), 0;
        isnt test_by('--all'), 0;
    };
};

sub test_by {
    my $run_opt = shift;

    $ENV{RELEASE_TESTING}   = 0;
    $ENV{AUTHOR_TESTING}    = 0;
    $ENV{AUTOMATED_TESTING} = 0;

    my $pid = fork;
    fail("Fork failed") unless defined $pid;
    if ($pid) {
        waitpid($pid, 0);
        return $?;
    }
    else {
        Minilla::CLI->new->run('test', $run_opt);
    }
}

done_testing;

