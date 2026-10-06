use strict;
use warnings;
use utf8;
use Test::More;

use lib "t/lib";
use Util;
use Archive::Tar;
use Digest::SHA qw(sha256_hex);
use Errno qw(EACCES);
use Fcntl qw(:mode);
use JSON::PP qw(decode_json);
use Test::Output qw(stdout_from output_from);

use Minilla::CLI::Dist;
use Minilla::Profile::Default;
use Minilla::Project;

my $guard = pushd(tempdir(CLEANUP => 1));

my $profile = Minilla::Profile::Default->new(
    author  => 'tokuhirom',
    dist    => 'Acme-Foo',
    path    => 'Acme/Foo.pm',
    suffix  => 'Foo',
    module  => 'Acme::Foo',
    version => '0.01',
    email   => 'tokuhirom@example.com',
);
$profile->generate();
write_minil_toml('Acme-Foo');
chmod(0755, 'Changes') or die "chmod: $!";

git_init();
git_config(qw(user.name tokuhirom));
git_config(qw(user.email tokuhirom@example.com));
git_add('.');
git_commit('-m', 'initial import');

local $ENV{SOURCE_DATE_EPOCH} = 1700000000;
my $stdout = stdout_from(sub { Minilla::CLI::Dist->run('--no-test') });
my $dist_path = catfile(Minilla::Project->new()->dir, 'Acme-Foo-0.01.tar.gz');
is_deeply(
    decode_json((split /\n/, $stdout)[-1]),
    { dist => 'Acme-Foo-0.01.tar.gz' },
    'minil dist logs the archive path relative to the current directory',
);
is(scalar(() = $stdout =~ /^\{/mg), 1, 'result is a single JSON line');
like($stdout, qr/\n\z/, 'result ends with a newline');
ok(-f $dist_path, 'logged archive exists in the project directory');
my $first_dist = slurp_raw('Acme-Foo-0.01.tar.gz');

utime(1800000000, 1800000000, 'Changes');
Minilla::CLI::Dist->run('--no-test');
my $second_dist = slurp_raw('Acme-Foo-0.01.tar.gz');

is(
    sha256_hex($second_dist),
    sha256_hex($first_dist),
    'minil dist creates a reproducible tarball when Changes is managed',
);

my $tar = Archive::Tar->new('Acme-Foo-0.01.tar.gz');
like(
    $tar->get_content('Acme-Foo-0.01/Changes'),
    qr/^0\.01 2023-11-14T22:13:20Z$/m,
    'Changes uses the canonical archive timestamp',
);
my ($changes) = $tar->get_files('Acme-Foo-0.01/Changes');
is(
    $changes->mode & (S_IRWXU | S_IRWXG | S_IRWXO),
    0644,
    'rewritten Changes is archived as 0644',
);

{
    no warnings 'redefine';
    local *Minilla::CLI::Dist::copy = sub { $! = EACCES; return };
    local $Minilla::Logger::COLOR = 0;
    my $error;
    my ($stdout, $stderr) = output_from(sub {
        eval { Minilla::CLI::Dist->run('--no-test') };
        $error = $@;
    });
    unlike($stdout, qr/^\{"dist":/m, 'copy failures do not log a successful result');
    isa_ok($error, 'Minilla::Error::CommandExit');
    like(
        $error->body,
        qr/^Failed to copy .+ to \Q$dist_path\E: .+\n\z/,
        'copy failures report the archive paths and error',
    );
    like($stderr, qr/^Failed to copy /m, 'copy failures are logged to standard error');
}

done_testing;
