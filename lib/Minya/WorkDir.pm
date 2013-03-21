package Minya::WorkDir;
use strict;
use warnings;
use utf8;
use Path::Tiny;
use Archive::Tar;
use File::pushd;
use Data::Dumper; # serializer

use Minya::Util qw(randstr);
use Minya::CPANMeta;
use Minya::FileGatherer;

use Moo;

has base_dir => (
    is => 'ro',
    required => 1,
);

has dir => (
    is => 'lazy',
);

has c => (
    is       => 'ro',
    required => 1,
);

has files => (
    is => 'lazy',
);

has prereq_specs => (
    is => 'lazy',
);

no Moo;

sub DEMOLISH {
    my $self = shift;
    unless ($self->c->debug) {
        path(path($self->dir)->dirname)->remove_tree({safe => 0});
    }
}

sub _build_dir {
    my $self = shift;
    my $dirname = $^O eq 'MSWin32' ? '_build' : '.build';
    path($self->base_dir(), $dirname, randstr(8));
}

sub _build_prereq_specs {
    my $self = shift;

    my $cpanfile = Module::CPANfile->load(path($self->base_dir, 'cpanfile'));
    return $cpanfile->prereq_specs;
}

sub _build_files {
    my $self = shift;

    my @files = Minya::FileGatherer->gather_files(
        $self->c->base_dir
    );
    \@files;
}

sub make_tar_ball {
    my ($class, $c, $test) = @_;

    my $work_dir = Minya::WorkDir->new(base_dir => $c->base_dir, c => $c);
    return $work_dir->build_tar_ball($test);
}

sub as_string {
    my $self = shift;
    $self->dir;
}

sub BUILD {
    my ($self) = @_;

    $self->c->infof("Creating working directory: %s\n", $self->dir);

    # copying
    path($self->dir)->mkpath;
    for my $src (@{$self->files}) {
        next if -d $src;
        my $dst = path($self->dir, path($src)->relative($self->c->base_dir));
        path($dst->dirname)->mkpath;
        path($src)->copy($dst);
    }

    $self->write_release_tests();
}

sub build_tar_ball {
    my ($self, $test) = @_;

    my $c = $self->c;

    my $verifier = Minya::PrereqVerifier->new(
        base_dir     => $self->base_dir,
        c            => $self->c,
        auto_install => $self->c->auto_install,
    );
    $verifier->verify([qw(runtime)], $_) for qw(requires recommends);
    if ($test) {
        $verifier->verify([qw(test)], $_) for qw(requires recommends);
    }

    my $guard = pushd($self->dir);

    $self->c->infof("Generating Build.PL\n");
    path('Build.PL')->spew($self->generate_build_pl());

    # Generate meta file
    {
        my $meta = Minya::CPANMeta->new(
            config       => $self->c->config,
            prereq_specs => $self->prereq_specs,
            base_dir     => '.',
        )->generate('stable');
        $meta->save('META.yml', {
            version => 1.4,
        });
        $meta->save('META.json', {
            version => 2.0,
        });
    }

    my @files = @{$self->files};
    push @files, qw(Build.PL LICENSE META.json META.yml);

    $self->c->infof("Writing MANIFEST file\n");
    {
        path('MANIFEST')->spew(join("\n", @files));
    }

    if ($test) {
        local $ENV{RELEASE_TESTING} = 1;
        $self->c->cmd('prove', '-r', '-l', 't', (-d 'xt' ? 'xt' : ()));
    }

    # Create tar ball
    my $tarball = sprintf('%s-%s.tar.gz', $self->c->config->name, $self->c->config->version);

    my $tar = Archive::Tar->new;
    for (@files) {
        $tar->add_data(path($self->c->config->{name} . '-' . $self->c->config->{version}, $_), path($_)->slurp);
    }
    $tar->write(path($self->c->base_dir, $tarball), COMPRESS_GZIP);
    $self->c->infof("Wrote %s\n", $tarball);

    return $tarball;
}

sub write_release_tests {
    my $self = shift;

    my $guard = pushd($self->dir);
    path('xt')->mkpath;

    path('xt/minimum_version.t')->spew(<<'...');
use Test::More;
eval "use Test::MinimumVersion 0.101080";
plan skip_all => "Test::MinimumVersion required for testing perl minimum version" if $@;
all_minimum_version_from_metayml_ok();
...

    path('xt/cpan_meta.t')->spew(<<'...');
use Test::More;
eval "use Test::CPAN::Meta";
plan skip_all => "Test::CPAN::Meta required for testing META.yml" if $@;
plan skip_all => "There is no META.yml" unless -f "META.yml";
meta_yaml_ok();
...

    path('xt/pod.t')->spew(<<'...');
use strict;
use Test::More;
eval "use Test::Pod 1.41";
plan skip_all => "Test::Pod 1.41 required for testing POD" if $@;
all_pod_files_ok();
...
}

sub generate_build_pl {
    my ($self, ) = @_;

    # TODO: Equivalent to M::I::GithubMeta is required?
    # TODO: ShareDir?

    local $Data::Dumper::Terse = 1;

    my $config = $self->c->config;
    my $prereq = $self->prereq_specs;
    my $args = +{
            dynamic_config => 0,

            no_index           => { 'directory' => ['inc'] },
            module_name        => $config->name,
            dist_name          => $config->dist_name,
            dist_version       => $config->version,
            license            => $config->license,
            script_files       => $config->script_files,
            configure_requires => +{
                'Module::Build' => 0.40,
                %{ $prereq->{configure}->{requires} || {} }
            },
            requires => +{
                perl => $config->perl_version,
                %{ $prereq->{runtime}->{requires} || {} },
            },
            build_requires => +{
                %{ $prereq->{test}->{requires} || {} }, ## When M::B support TEST_REQUIRES?
                %{ $prereq->{build}->{requires} || {} },
            },
            test_files => 't/',

            recursive_test_files => 1,

            create_readme => 1,
    };
    $args->{share_dir} = $config->share_dir if $config->share_dir;
    $args = Dumper($args);
    return sprintf(<<'...', $config->perl_version, $args);
use strict;
use Module::Build;
use %s;

my $builder = Module::Build->new(%%{
%s
});
$builder->create_build_script();
...
}

1;

