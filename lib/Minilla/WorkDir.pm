package Minilla::WorkDir;
use strict;
use warnings;
use utf8;
use Path::Tiny;
use Archive::Tar;
use File::pushd;
use Data::Dumper; # serializer
use File::Spec::Functions qw(splitdir);
use File::Spec;
use Time::Piece qw(gmtime);
use File::Basename qw(dirname);
use File::Path qw(mkpath);
use File::Copy qw(copy);

use Minilla::Logger;
use Minilla::Util qw(randstr cmd cmd_perl slurp slurp_raw spew_raw pod_escape);
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
    path($self->project->dir, $dirname, randstr(8));
}

sub _build_prereq_specs {
    my $self = shift;

    my $cpanfile = Module::CPANfile->load(path($self->project->dir, 'cpanfile'));
    return $cpanfile->prereq_specs;
}

sub _build_manifest_files {
    my $self = shift;
    [do {
        my %h;
        grep {!$h{$_}++} @{$self->files}, qw(Build.PL LICENSE META.json META.yml MANIFEST);
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
        my $dst = path($self->dir, path($src)->relative($self->project->dir));
        mkpath($dst->dirname);
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
        my $meta = $self->project->cpan_meta('stable');
        $meta->save('META.yml', {
            version => 1.4,
        });
        $meta->save('META.json', {
            version => 2.0,
        });
    }

    {
        infof("Writing MANIFEST file\n");
        path('MANIFEST')->spew(join("\n", @{$self->manifest_files}));
    }

    $self->project->regenerate_files();
    $self->_rewrite_changes();
    $self->_rewrite_pod();

    Minilla::ReleaseTest->write_release_tests($self->project, $self->dir);

    cmd_perl('Build.PL');
    cmd_perl('Build', 'build');
    cmd_perl('Build', 'build');
}

sub _rewrite_changes {
    my $self = shift;

    my $orig = path('Changes')->slurp_raw();
    $orig =~ s!\{\{\$NEXT\}\}!
        $self->project->version . ' ' . $self->changes_time->strftime('%Y-%m-%dT%H:%M:%SZ')
    !e;
    path('Changes')->spew_raw($orig);
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

    $self->project->verify_prereqs([qw(runtime)], $_) for qw(requires recommends);
    $self->project->verify_prereqs([qw(test)], $_) for qw(requires recommends);

    eval {
        my $guard = pushd($self->dir);
        cmd_perl('Build', 'test');
    };
    return $@ ? 1 : 0;
}

sub dist {
    my ($self) = @_;

    $self->{tarball} ||= do {
        $self->build();

        my $guard = pushd($self->dir);

        # Create tar ball
        my $tarball = sprintf('%s-%s.tar.gz', $self->project->dist_name, $self->project->version);

        my $tar = Archive::Tar->new;
        for (@{$self->manifest_files}) {
            $tar->add_data(path($self->project->dist_name . '-' . $self->project->version, $_), path($_)->slurp);
        }
        $tar->write($tarball, COMPRESS_GZIP);
        infof("Wrote %s\n", $tarball);

        File::Spec->rel2abs($tarball);
    };
}

1;
