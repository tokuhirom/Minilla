use strict;
use warnings;
use Test::More;
use Test::Requires 'Version::Next', 'CPAN::Uploader';
use lib 't/lib';
use Util;
use Minilla::CLI;
use Minilla::Profile::ModuleBuild;
use Minilla::Release::UploadToCPAN;

if (@ARGV && $ARGV[0] eq '--release-helper') {
    no warnings 'redefine';
    local *CPAN::Uploader::read_config_file = sub { die "Unexpected credential access\n" };
    local *CPAN::Uploader::new = sub { die "Unexpected upload\n" };
    local *Minilla::Release::UploadToCPAN::prompt = sub { die "Unexpected upload prompt\n" };
    exit Minilla::CLI->run('--no-auto-install', 'release', '--skip-prepare', '--no-test');
}

my $test = File::Spec->rel2abs($0);
my $lib = File::Spec->rel2abs('lib');
my $test_lib = File::Spec->rel2abs('t/lib');
my $repo = tempdir(CLEANUP => 1);
{
    my $guard = pushd($repo);
    cmd('git', 'init', '--bare');
}
my $guard = pushd(tempdir(CLEANUP => 1));
Minilla::Profile::ModuleBuild->new(
    author => 'hoge', dist => 'Acme-Foo', module => 'Acme::Foo',
    path => 'Acme/Foo.pm', version => '0.01',
)->generate();
write_minil_toml('Acme-Foo');
git_init_add_commit();
git_remote('add', 'origin', "file://$repo");
Minilla::CLI->run('prepare', '0.01');
git_add('.');
git_commit('-m', 'prepare release');
my $original = slurp('Changes');

local $ENV{FAKE_RELEASE} = 0;
local $ENV{PERL_MM_USE_DEFAULT} = 0;
my ($status, $message) = run_with_open_stdin(
    30, $^X, "-I$lib", "-I$test_lib", $test, '--release-helper',
);
is $status >> 8, 1, 'full release fails with its input pipe still open';
like $message, qr/CPAN upload requires confirmation from a terminal/, 'fails at upload confirmation';
unlike $message, qr/Unexpected|Release to CPAN/, 'does not prompt, read credentials, or upload';
is slurp('Changes'), $original, 'failed release does not rewrite Changes';
is `git tag --list`, '', 'failed release creates no tag';
my @commits = split /\n/, `git rev-list --all`;
is scalar @commits, 2, 'failed release creates no commit';

done_testing;
