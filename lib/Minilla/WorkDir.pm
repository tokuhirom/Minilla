package Minilla::WorkDir;
use strict;
use warnings;
use utf8;
use Path::Tiny;
use Archive::Tar;
use File::pushd;
use Data::Dumper; # serializer
use File::Spec::Functions qw(splitdir);
use Time::Piece qw(gmtime);
use File::Basename qw(dirname);

use Minilla::Logger;
use Minilla::Util qw(randstr cmd slurp);
use Minilla::FileGatherer;
use Minilla::ReleaseTest;

use Moo;

has project => (
    is => 'ro',
    required => 1,
);

has dir => (
    is => 'lazy',
);

has files => (
    is => 'lazy',
);

has [qw(prereq_specs)] => (
    is => 'lazy',
);

has changes_time => (
    is => 'lazy',
);

no Moo;

sub _build_changes_time { scalar(gmtime()) }

sub DEMOLISH {
    my $self = shift;
    unless ($Minilla::DEBUG) {
        path(path($self->dir)->dirname)->remove_tree({safe => 0});
    }
}

sub _build_dir {
    my $self = shift;
    my $dirname = $^O eq 'MSWin32' ? '_build' : '.build';
    path($self->project->dir, $dirname, randstr(8));
}

sub _build_prereq_specs {
    my $self = shift;

    my $cpanfile = Module::CPANfile->load(path($self->project->dir, 'cpanfile'));
    return $cpanfile->prereq_specs;
}

sub _build_files {
    my $self = shift;

    my @files = Minilla::FileGatherer->gather_files(
        $self->project->dir
    );
    \@files;
}

sub as_string {
    my $self = shift;
    $self->dir;
}

sub BUILD {
    my ($self) = @_;

    infof("Creating working directory: %s\n", $self->dir);

    # copying
    path($self->dir)->mkpath;
    for my $src (@{$self->files}) {
        next if -d $src;
        debugf("Copying %s\n", $src);
        my $dst = path($self->dir, path($src)->relative($self->project->dir));
        path($dst->dirname)->mkpath;
        path($src)->copy($dst);
    }
}

sub build {
    my ($self) = @_;

    return if $self->{build}++;

    my $guard = pushd($self->dir);

    # Generate meta file
    {
        my $meta = $self->project->cpan_meta('stable');
        $meta->save('META.yml', {
            version => 1.4,
        });
        $meta->save('META.json', {
            version => 2.0,
        });
    }

    my @files = @{$self->files};

    infof("Writing MANIFEST file\n");
    {
        path('MANIFEST')->spew(join("\n", @files));
    }

    $self->_rewrite_changes();

    Minilla::ReleaseTest->write_release_tests($self->project, $self->dir);

    if (slurp('Build.PL') =~ /use\s+Module::Build;/) {
        cmd($^X, 'Build.PL');
        cmd($^X, 'Build', 'build');
    }
}

sub _rewrite_changes {
    my $self = shift;

    my $orig = path('Changes')->slurp_raw();
    $orig =~ s!\{\{\$NEXT\}\}!
        $self->project->version . ' ' . $self->changes_time->strftime('%Y-%m-%dT%H:%M:%SZ')
    !e;
    path('Changes')->spew_raw($orig);
}

sub dist_test {
    my $self = shift;

    $self->build();

    $self->project->verify_prereqs([qw(runtime)], $_) for qw(requires recommends);
    $self->project->verify_prereqs([qw(test)], $_) for qw(requires recommends);

    {
        my $guard = pushd($self->dir);
        if (slurp('Build.PL') =~ /use\s+Module::Build;/) {
            cmd($^X, 'Build', 'test');
        } else {
            my @dirs = grep { -d $_ } qw(t xt);
            cmd('prove', '-r', '-l', @dirs);
        }
    }
}

sub dist {
    my ($self) = @_;

    $self->{tarball} ||= do {
        $self->build();

        my $guard = pushd($self->dir);

        # Create tar ball
        my $tarball = sprintf('%s-%s.tar.gz', $self->project->dist_name, $self->project->version);

        my $tar = Archive::Tar->new;
        for (@{$self->files}, qw(Build.PL LICENSE META.json META.yml MANIFEST)) {
            $tar->add_data(path($self->project->dist_name . '-' . $self->project->version, $_), path($_)->slurp);
        }
        $tar->write(path($tarball), COMPRESS_GZIP);
        infof("Wrote %s\n", $tarball);

        path($tarball)->absolute;
    };
}

1;
