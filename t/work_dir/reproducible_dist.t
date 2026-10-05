use strict;
use warnings;
use utf8;
use Test::More;

use lib "t/lib";
use Util;
use Archive::Tar;
use Digest::SHA qw(sha256_hex);
use Fcntl qw(:mode);
use File::Path qw(mkpath);
use File::Spec::Functions qw(catfile);

use Minilla::WorkDir;

my $long_file = ('l' x 110) . '.txt';

{
    package Local::Project;

    sub new {
        my ($class, %args) = @_;
        return bless \%args, $class;
    }

    sub dir         { $_[0]->{dir} }
    sub files       { $_[0]->{files} }
    sub dist_name   { 'Acme-Foo' }
    sub version     { '0.01' }
    sub script_files { "glob('script/*'), glob('bin/*')" }
}

{
    package Local::WorkDir;
    use parent 'Minilla::WorkDir';

    sub build { }
}

sub slurp_bytes {
    my ($path) = @_;
    open my $fh, '<:raw', $path or die "Cannot open $path: $!";
    return scalar do { local $/; <$fh> };
}

sub create_work_dir {
    my ($project, $dir, $generated_mode) = @_;
    my $work_dir = Local::WorkDir->new(
        project        => $project,
        dir            => $dir,
        cleanup        => 0,
        manifest_files => [
            'regular.txt',
            'script/generated',
            'executable.pl',
            'generated.txt',
            $long_file,
        ],
    );

    mkpath(catfile($dir, 'script'));
    spew(catfile($dir, 'script/generated'), "#!/usr/bin/env perl\n");
    spew(catfile($dir, 'generated.txt'), "generated\n");
    chmod($generated_mode, catfile($dir, 'script/generated')) or die "chmod: $!";
    chmod($generated_mode, catfile($dir, 'generated.txt')) or die "chmod: $!";
    return $work_dir;
}

sub archive_entries {
    my ($path) = @_;
    my $tar = Archive::Tar->new;
    $tar->read($path, 1) or die $tar->error;
    return ($tar, $tar->get_files);
}

subtest 'SOURCE_DATE_EPOCH creates reproducible archives' => sub {
    my $guard = pushd(tempdir(CLEANUP => 1));

    spew('regular.txt', "regular\n");
    spew('executable.pl', "#!/usr/bin/env perl\n");
    spew($long_file, "long path\n");
    chmod(0644, 'regular.txt') or die "chmod: $!";
    chmod(0755, 'executable.pl') or die "chmod: $!";

    git_init();
    git_add('.');
    {
        local $ENV{GIT_AUTHOR_DATE} = '1600000000 +0000';
        local $ENV{GIT_COMMITTER_DATE} = '1600000000 +0000';
        git_commit('-m', 'initial import');
    }

    my $project = Local::Project->new(
        dir   => File::Spec->rel2abs('.'),
        files => ['regular.txt', 'executable.pl', $long_file],
    );

    local $ENV{SOURCE_DATE_EPOCH} = 1700000000;
    my $first = create_work_dir($project, 'build-one', 0777)->dist;
    my $first_bytes = slurp_bytes($first);

    chmod(0777, 'regular.txt') or die "chmod: $!";
    chmod(0600, 'executable.pl') or die "chmod: $!";
    utime(1800000000, 1800000000, 'regular.txt', 'executable.pl', $long_file);
    sleep 1;

    my $second = create_work_dir($project, 'build-two', 0600)->dist;
    my $second_bytes = slurp_bytes($second);

    is(
        sha256_hex($second_bytes),
        sha256_hex($first_bytes),
        'archive digest is independent of filesystem metadata',
    );

    my ($tar, @entries) = archive_entries($second);
    is_deeply(
        [map { $_->full_path } @entries],
        [
            'Acme-Foo-0.01/executable.pl',
            'Acme-Foo-0.01/generated.txt',
            "Acme-Foo-0.01/$long_file",
            'Acme-Foo-0.01/regular.txt',
            'Acme-Foo-0.01/script/generated',
        ],
        'entries are ordered lexicographically',
    );

    my %entries = map { $_->full_path => $_ } @entries;
    is(
        $entries{'Acme-Foo-0.01/regular.txt'}->mode & (S_IRWXU | S_IRWXG | S_IRWXO),
        0644,
        'Git 100644 is archived as 0644',
    );
    is(
        $entries{'Acme-Foo-0.01/executable.pl'}->mode & (S_IRWXU | S_IRWXG | S_IRWXO),
        0755,
        'Git 100755 is archived as 0755',
    );
    is(
        $entries{'Acme-Foo-0.01/script/generated'}->mode & (S_IRWXU | S_IRWXG | S_IRWXO),
        0755,
        'generated script is archived as 0755',
    );
    is(
        $entries{'Acme-Foo-0.01/generated.txt'}->mode & (S_IRWXU | S_IRWXG | S_IRWXO),
        0644,
        'generated regular file is archived as 0644',
    );

    for my $entry (@entries) {
        is($entry->mtime, 1700000000, $entry->full_path . ' has canonical mtime');
        is($entry->uid, 0, $entry->full_path . ' has canonical uid');
        is($entry->gid, 0, $entry->full_path . ' has canonical gid');
        is($entry->uname, '', $entry->full_path . ' has empty uname');
        is($entry->gname, '', $entry->full_path . ' has empty gname');
    }

    is(
        unpack('H*', substr($second_bytes, 0, 10)),
        '1f8b08000000000000ff',
        'gzip header has no timestamp, filename, or comment',
    );
};

subtest 'Git HEAD timestamp is the fallback' => sub {
    my $guard = pushd(tempdir(CLEANUP => 1));

    spew('regular.txt', "regular\n");
    git_init();
    git_add('.');
    {
        local $ENV{GIT_AUTHOR_DATE} = '1650000000 +0000';
        local $ENV{GIT_COMMITTER_DATE} = '1650000000 +0000';
        git_commit('-m', 'initial import');
    }

    my $project = Local::Project->new(
        dir   => File::Spec->rel2abs('.'),
        files => ['regular.txt'],
    );

    local $ENV{SOURCE_DATE_EPOCH};
    delete $ENV{SOURCE_DATE_EPOCH};
    my $first = Local::WorkDir->new(
        project        => $project,
        dir            => 'build-one',
        cleanup        => 0,
        manifest_files => ['regular.txt'],
    )->dist;
    my $second = Local::WorkDir->new(
        project        => $project,
        dir            => 'build-two',
        cleanup        => 0,
        manifest_files => ['regular.txt'],
    )->dist;

    is(
        sha256_hex(slurp_bytes($second)),
        sha256_hex(slurp_bytes($first)),
        'Git timestamp archives are reproducible',
    );
    my ($tar, @entries) = archive_entries($second);
    is($entries[0]->mtime, 1650000000, 'Git HEAD timestamp is used');
};

subtest 'legacy archive path remains available without a timestamp' => sub {
    my $guard = pushd(tempdir(CLEANUP => 1));

    spew('regular.txt', "regular\n");
    git_init();
    git_add('.');

    my $project = Local::Project->new(
        dir   => File::Spec->rel2abs('.'),
        files => ['regular.txt'],
    );

    local $ENV{SOURCE_DATE_EPOCH};
    delete $ENV{SOURCE_DATE_EPOCH};
    my $dist = Local::WorkDir->new(
        project        => $project,
        dir            => 'build',
        cleanup        => 0,
        manifest_files => ['regular.txt'],
    )->dist;
    ok(-f $dist, 'distribution is created without SOURCE_DATE_EPOCH or HEAD');
};

done_testing;
