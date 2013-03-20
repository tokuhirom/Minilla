package Minya::WorkDir;
use strict;
use warnings;
use utf8;
use Path::Tiny;
use Archive::Tar;
use File::pushd;
use Data::Dumper; # serializer

use Moo;

has dir => (
    is => 'ro',
);

no Moo;

sub as_string {
    my $self = shift;
    $self->dir;
}

sub setup {
    my ($self, $c) = @_;

    $c->infof("Creating working directory: %s\n", $self->dir);

    my @files = $c->gather_files();

    # copying
    path($self->dir)->mkpath;
    for my $src (@files) {
        next if -d $src;
        my $dst = path($self->dir, path($src)->relative($c->base_dir));
        path($dst->dirname)->mkpath;
        path($src)->copy($dst);
    }

    $self->write_release_tests();
}

sub build_tar_ball {
    my ($self, $c, $test) = @_;

    $c->verify_dependencies([qw(runtime)], $_) for qw(requires recommends);
    if ($test) {
        $c->verify_dependencies([qw(test)], $_) for qw(requires recommends);
    }

    my $guard = pushd($self->dir);

    $c->infof("Generating Build.PL\n");
    path('Build.PL')->spew($self->generate_build_pl($c));

    # Generate meta file
    {
        my $meta = $c->generate_meta();
        $meta->save('META.yml', {
            version => 1.4,
        });
        $meta->save('META.json', {
            version => 2.0,
        });
    }

    my @files = $c->gather_files();
    push @files, qw(Build.PL LICENSE META.json META.yml);

    $c->infof("Writing MANIFEST file\n");
    {
        path('MANIFEST')->spew(join("\n", @files));
    }

    if ($test) {
        local $ENV{RELEASE_TESTING} = 1;
        $c->cmd('prove', '-r', '-l', 't', (-d 'xt' ? 'xt' : ()));
    }

    # Create tar ball
    my $tarball = sprintf('%s-%s.tar.gz', $c->config->name, $c->config->version);

    my $tar = Archive::Tar->new;
    for (@files) {
        $tar->add_data(path($c->config->{name} . '-' . $c->config->{version}, $_), path($_)->slurp);
    }
    $tar->write(path($c->base_dir, $tarball), COMPRESS_GZIP);
    $c->infof("Wrote %s\n", $tarball);

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
    my ($self, $c ) = @_;

    # TODO: Equivalent to M::I::GithubMeta is required?
    # TODO: ShareDir?

    local $Data::Dumper::Terse = 1;

    my $config = $c->config;
    my $prereq = $c->prereq_specs;
    my $args = +{
            dynamic_config => 0,

            no_index           => { 'directory' => ['inc'] },
            name               => $config->name,
            dist_name          => $config->name,
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
            build_requires => +{ %{ $prereq->{build}->{requires} || {} }, },
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

my $builder = Module::Build->new(
%s
);
$builder->create_build_script();
...
}

1;

