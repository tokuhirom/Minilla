package Minilla::WorkDir;
use strict;
use warnings;
use utf8;
use Archive::Tar;
use IO::Compress::Gzip qw(gzip $GzipError);
use File::pushd;
use Data::Dumper; # serializer
use File::Spec::Functions qw(splitdir);
use File::Spec;
use Time::Piece qw(gmtime);
use File::Basename qw(dirname);
use File::Path qw(mkpath);
use File::Copy qw(copy);
use Config;
use CPAN::Meta;

use Minilla::Logger;
use Minilla::Changes;
use Minilla::Util qw(randstr cmd cmd_perl slurp slurp_raw spew spew_raw pod_escape);
use Minilla::FileGatherer;
use Minilla::ReleaseTest;

use Moo;

has project => (
    is => 'ro',
    required => 1,
    handles => [qw(files)],
);

has dir => (
    is => 'lazy',
    isa => sub {
        Carp::confess("'dir' must not be undef") unless defined $_[0];
    },
);

has manifest_files => (
    is => 'lazy',
);

has [qw(prereq_specs)] => (
    is => 'lazy',
);

has 'cleanup' => (
    is => 'ro',
    default => sub { $Minilla::DEBUG ? 0 : 1 },
);

has 'skip_prepare' => (
    is => 'ro',
    default => sub { 0 },
);

has changes_time => (
    is => 'lazy',
);

no Moo;

sub _build_changes_time { scalar(gmtime()) }

sub DEMOLISH {
    my $self = shift;
    if ($self->cleanup) {
        infof("Removing %s\n", $self->dir);
        File::Path::rmtree($self->dir)
    }
}

sub _build_dir {
    my $self = shift;
    my $dirname = $^O eq 'MSWin32' ? '_build' : '.build';
    File::Spec->catfile($self->project->dir, $dirname, randstr(8));
}

sub _build_prereq_specs {
    my $self = shift;

    my $cpanfile = Module::CPANfile->load(File::Spec->catfile($self->project->dir, 'cpanfile'));
    return $cpanfile->prereq_specs;
}

sub _build_manifest_files {
    my $self = shift;
    my @files = (@{$self->files}, qw(LICENSE META.json META.yml MANIFEST));
    if (-f File::Spec->catfile($self->dir, 'Makefile.PL')) {
        push @files, 'Makefile.PL';
    } else {
        push @files, 'Build.PL';
    }

    [do {
        my %h;
        grep {!$h{$_}++} @files;
    }];
}

sub as_string {
    my $self = shift;
    $self->dir;
}

sub BUILD {
    my ($self) = @_;

    infof("Creating working directory: %s\n", $self->dir);

    # copying
    mkpath($self->dir);
    for my $src (@{$self->files}) {
        next if -d $src;
        debugf("Copying %s\n", $src);

        if (not -e $src) {
            warnf("Trying to copy non-existing file '$src', ignored\n");
            next;
        }
        my $dst = File::Spec->catfile($self->dir, File::Spec->abs2rel($src, $self->project->dir));
        mkpath(dirname($dst));
        infof("cp %s %s\n", $src, $dst);
        copy($src => $dst) or die "Copying failed: $src $dst, $!\n";
        chmod((stat($src))[2], $dst) or die "Cannot change mode: $dst, $!\n";
    }
}

sub build {
    my ($self) = @_;

    return if $self->{build}++;

    my $guard = pushd($self->dir);

    infof("Building %s\n", $self->dir);

    # Generate meta file
    {
        my $meta = $self->skip_prepare
            ? CPAN::Meta->load_file('META.json', { lazy_validation => 0 })
            : $self->project->cpan_meta();
        $meta->save('META.yml', {
            version => '1.4',
        });
        unless ($self->skip_prepare) {
            $meta->save('META.json', {
                version => '2',
            });
        }
    }

    {
        infof("Writing MANIFEST file\n");
        spew('MANIFEST', join("\n", @{$self->manifest_files}));
    }

    $self->project->regenerate_files() unless $self->skip_prepare;
    $self->_rewrite_changes() if $self->project->manage_changes;
    $self->_rewrite_pod();

    unless ($ENV{MINILLA_DISABLE_WRITE_RELEASE_TEST}) { # DO NOT USE THIS ENVIRONMENT VARIABLE.
        Minilla::ReleaseTest->write_release_tests($self->project, $self->dir);
    }

    if (-f 'Build.PL') {
        cmd_perl('Build.PL');
        cmd_perl('Build', 'build');
    } elsif (-f 'Makefile.PL') {
        cmd_perl('Makefile.PL');
        cmd($Config{make});
    } else {
       die "There is no Makefile.PL/Build.PL";
    }
}

sub _rewrite_changes {
    my $self = shift;

    my $orig = slurp_raw('Changes');
    my $version = $self->project->version;
    if (Minilla::Changes::is_prepared($orig, $version)) {
        $orig =~ s!
            ^\{\{\$NEXT\}\}\h*\R(?:\h*\R)*
            (?=\Q$version\E(?:\h|\R|\z))
        !!mx;
    } else {
        $orig =~ s!\{\{\$NEXT\}\}!
            $version . ' ' . $self->changes_time->strftime('%Y-%m-%dT%H:%M:%SZ')
        !e;
    }
    spew_raw('Changes', $orig);
}

sub _rewrite_pod {
    my $self = shift;

    # Disabled this feature.
#   my $orig =slurp_raw($self->project->main_module_path);
#   if (@{$self->project->contributors}) {
#       $orig =~ s!
#           (^=head \d \s+ (?:authors?)\b \s*)
#           (.*?)
#           (^=head \d \s+ | \z)
#       !
#           (       $1
#               . $2
#               . "=head1 CONTRIBUTORS\n\n=over 4\n\n"
#               . join( '', map { "=item $_\n\n" } map { pod_escape($_) } @{ $self->project->contributors } )
#               . "=back\n\n"
#               . $3 )
#       !ixmse;
#       spew_raw($self->project->main_module_path => $orig);
#   }
}

# Return non-zero if fail
sub dist_test {
    my ($self, @targets) = @_;

    $self->build();

    $self->project->verify_prereqs();

    eval {
        my $guard = pushd($self->dir);
        $self->project->module_maker->run_tests();
    };
    return $@ ? 1 : 0;
}

sub dist {
    my ($self) = @_;

    $self->{tarball} ||= do {
        my $archive_timestamp = $self->_archive_timestamp();
        $self->build();

        my $guard = pushd($self->dir);

        # Create tar ball
        my $tarball = sprintf('%s-%s.tar.gz', $self->project->dist_name, $self->project->version);

        if (defined $archive_timestamp) {
            $self->_write_reproducible_tarball($tarball, $archive_timestamp);
            infof("Wrote %s\n", $tarball);
        } else {
            my $force_mode = 0;
            my $tar = Archive::Tar->new;
            for my $file (@{$self->manifest_files}) {
                my $filename = File::Spec->catfile($self->project->dist_name . '-' . $self->project->version, $file);
                my $data = slurp($file);
                my $mode = (stat($file))[2];

                # On Windows, (stat($file))[2] * ALWAYS * results in octal 0100666 (which means it is
                # world writeable). World writeable files are always rejected by PAUSE. The solution is to
                # change a file mode octal 0100666 to octal 000664, such that it is * NOT * world
                # writeable. This works on Windows, as well as on other systems (Linux, Mac, etc...), because
                # the filemode 0100666 only occurs on Windows. (If it occurred on Linux, it would be wrong anyway)

                if ($mode == 0100666) {
                    $mode = 0644;
                    $force_mode++;
                }

                $tar->add_data($filename, $data, { mode => $mode });
            }
            $tar->write($tarball, COMPRESS_GZIP);
            infof("Wrote %s\n", $tarball.($force_mode == 0 ? '' : ' --> forced to mode 000664'));
        }

        File::Spec->rel2abs($tarball);
    };
}

sub _archive_timestamp {
    my ($self) = @_;

    if (exists $ENV{SOURCE_DATE_EPOCH}) {
        my $timestamp = $ENV{SOURCE_DATE_EPOCH};
        die "SOURCE_DATE_EPOCH must be a non-negative integer\n"
            unless defined $timestamp && $timestamp =~ /\A[0-9]+\z/;
        die "SOURCE_DATE_EPOCH is too large for a tar header\n"
            if $timestamp > 8_589_934_591;
        return 0 + $timestamp;
    }

    my $guard = pushd($self->project->dir);
    open my $verify_fh, '-|', 'git', 'rev-parse', '--verify', '--quiet', 'HEAD'
        or return;
    my $head = <$verify_fh>;
    return unless close $verify_fh && defined $head;

    open my $fh, '-|', 'git', 'log', '-1', '--format=%ct'
        or return;
    my $timestamp = <$fh>;
    return unless close $fh;
    chomp $timestamp if defined $timestamp;
    return unless defined $timestamp && $timestamp =~ /\A[0-9]+\z/;
    return 0 + $timestamp;
}

sub _write_reproducible_tarball {
    my ($self, $tarball, $timestamp) = @_;

    my $index_modes = $self->_git_index_modes();
    my $generated_executables = $self->_generated_executable_files();
    my $prefix = $self->project->dist_name . '-' . $self->project->version;
    my $tar = Archive::Tar->new;

    for my $file (sort { _archive_path($a) cmp _archive_path($b) } @{$self->manifest_files}) {
        my $archive_file = _archive_path($file);
        my $mode = exists $index_modes->{$archive_file}
            ? ($index_modes->{$archive_file} eq '100755' ? 0755 : 0644)
            : $generated_executables->{$archive_file} ? 0755 : 0644;

        $tar->add_data(
            "$prefix/$archive_file",
            slurp_raw($file),
            {
                mode  => $mode,
                mtime => $timestamp,
                uid   => 0,
                gid   => 0,
                uname => '',
                gname => '',
            },
        );
    }

    my $tar_data = $tar->write();
    die "Cannot create tar stream: " . $tar->error . "\n"
        unless defined $tar_data;
    $tar_data = _canonicalize_tar_headers($tar_data, $timestamp);

    gzip(
        \$tar_data => $tarball,
        Minimal => 1,
        Time    => 0,
        Level   => 6,
    ) or die "Cannot write $tarball: $GzipError\n";
}

sub _git_index_modes {
    my ($self) = @_;

    my $guard = pushd($self->project->dir);
    open my $fh, '-|', 'git', 'ls-files', '--stage', '--recurse-submodules', '-z'
        or die "Cannot read Git index: $!\n";
    local $/ = "\0";
    my %modes;
    while (my $entry = <$fh>) {
        $entry =~ s/\0\z//;
        my ($mode, $stage, $path) = $entry =~ /\A([0-9]+) [0-9a-f]+ ([0-3])\t(.*)\z/s;
        next unless defined $path && $stage == 0;
        $modes{_archive_path($path)} = $mode;
    }
    close $fh or die "Cannot read Git index\n";
    return \%modes;
}

sub _generated_executable_files {
    my ($self) = @_;

    my @files = eval $self->project->script_files;
    die "Cannot evaluate script_files: $@" if $@;
    return +{ map { _archive_path($_) => 1 } @files };
}

sub _archive_path {
    my ($path) = @_;
    $path =~ s!\\!/!g if $^O eq 'MSWin32';
    return $path;
}

sub _canonicalize_tar_headers {
    my ($tar_data, $timestamp) = @_;

    my $offset = 0;
    while ($offset + 512 <= length $tar_data) {
        my $header = substr($tar_data, $offset, 512);
        last if $header eq "\0" x 512;

        my $size = substr($header, 124, 12);
        $size =~ s/\0.*\z//s;
        $size =~ s/\A\s+|\s+\z//g;
        $size = length($size) ? oct($size) : 0;

        my $type = substr($header, 156, 1);
        my $mode = $type eq '5' ? 0755
                 : $type eq 'L' ? 0644
                 : oct(substr($header, 100, 8));

        substr($header, 100, 8) = sprintf("%07o\0", $mode);
        substr($header, 108, 8) = sprintf("%07o\0", 0);
        substr($header, 116, 8) = sprintf("%07o\0", 0);
        substr($header, 136, 12) = sprintf("%011o\0", $timestamp);
        substr($header, 265, 32) = "\0" x 32;
        substr($header, 297, 32) = "\0" x 32;
        substr($header, 148, 8) = ' ' x 8;
        my $checksum = unpack('%32C*', $header);
        substr($header, 148, 8) = sprintf("%06o\0 ", $checksum);
        substr($tar_data, $offset, 512) = $header;

        $offset += 512 + int(($size + 511) / 512) * 512;
    }

    return $tar_data;
}

sub run {
    my ($self, @cmd) = @_;
    $self->build();

    eval {
        my $guard = pushd($self->dir);
        cmd(@cmd);
    };
    return $@ ? 1 : 0;
}

1;
