use strict;
use warnings;
use utf8;
use Test::More;

use lib "t/lib";
use Util;
use File::Spec::Functions qw(catfile);
use Archive::Tar;
use Fcntl qw(:mode);

use Minilla::Profile::Default;
use Minilla::Project;
use Minilla::Git;

subtest 'copy' => sub {
    my $guard = pushd(tempdir(CLEANUP => 1));

    my $profile = Minilla::Profile::Default->new(
        author => 'tokuhirom',
        dist => 'Acme-Foo',
        path => 'Acme/Foo.pm',
        suffix => 'Foo',
        module => 'Acme::Foo',
        version => '0.01',
        email => 'tokuhirom@example.com',
    );
    $profile->generate();
    mkdir 'bin';
    spew('bin/foo', '');
    chmod(0777, 'bin/foo') or die "chmod: $!";
    write_minil_toml('Acme-Foo');

    git_init_add_commit();
    chmod(0600, 'bin/foo') or die "chmod: $!";

    my $work_dir = Minilla::Project->new()->work_dir;
    ok($work_dir);
    ok -f catfile($work_dir->dir, 'bin/foo');
    SKIP: {
        skip "File permissions are not portable", 2 if $^O eq 'MSWin32';
        ok -x catfile($work_dir->dir, 'bin/foo');
        is(
            (stat(catfile($work_dir->dir, 'bin/foo')))[2] & (S_IRWXU | S_IRWXG | S_IRWXO),
            0755,
            'Git index mode is applied to the copied file',
        );
    }
};

done_testing;
