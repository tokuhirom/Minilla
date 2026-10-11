use strict;
use warnings;
use Test::More;
use Test::Requires 'CPAN::Uploader';
use Test::Output qw(stderr_like);
use File::Temp qw(tempdir);
use File::pushd;
use File::Spec;
use Minilla;
use Minilla::Release::UploadToCPAN;
use Minilla::Util qw(spew_raw);

{
    package Local::Project;
    sub new { bless { release => {} }, shift }
    sub work_dir { shift }
    sub dist { 'release.tar.gz' }
    sub config { shift }
}

my $guard = pushd(tempdir(CLEANUP => 1));
my $project = Local::Project->new;
Minilla::Release::UploadToCPAN->init;
local $Minilla::DEBUG = 0;
local $ENV{FAKE_RELEASE} = 0;
local *STDIN;
open STDIN, '<', File::Spec->devnull or die "Cannot redirect standard input: $!";
no warnings 'redefine';
local *Minilla::Release::UploadToCPAN::prompt = sub { die "Unexpected upload prompt\n" };
local *CPAN::Uploader::read_config_file = sub { die "Unexpected credential access\n" };
local *CPAN::Uploader::new = sub { die "Unexpected upload\n" };

spew_raw('release.tar.gz', '');
my $error;
stderr_like {
    eval { Minilla::Release::UploadToCPAN->run($project, {}) };
    $error = $@;
} qr/CPAN upload requires confirmation from a terminal/, 'noninteractive uploading fails before prompting or reading credentials';
isa_ok $error, 'Minilla::Error::CommandExit';
ok -f 'release.tar.gz', 'failed confirmation keeps the release archive';

for my $mode (qw(dry_run fake_release disabled)) {
    spew_raw('release.tar.gz', '');
    local $ENV{FAKE_RELEASE} = $mode eq 'fake_release' ? 1 : 0;
    local $project->{release}->{do_not_upload_to_cpan} = $mode eq 'disabled' ? 1 : 0;
    Minilla::Release::UploadToCPAN->run($project, { dry_run => $mode eq 'dry_run' ? 1 : 0 });
    ok !-f 'release.tar.gz', "$mode bypasses confirmation and retains archive cleanup behavior";
}

subtest 'interactive upload still requires confirmation' => sub {
    spew_raw('release.tar.gz', '');
    local *Minilla::Release::UploadToCPAN::is_interactive = sub { 1 };
    local *CPAN::Uploader::read_config_file = sub {
        return { user => 'test', password => 'test' };
    };
    local *Minilla::Release::UploadToCPAN::prompt = sub {
        like $_[0], qr/Release to CPAN/, 'asks to confirm uploading';
        return 'n';
    };
    stderr_like {
        eval { Minilla::Release::UploadToCPAN->run($project, {}) };
        $error = $@;
    } qr/Giving up/, 'declining the prompt cancels the upload';
    isa_ok $error, 'Minilla::Error::CommandExit';
};

done_testing;
