package Minilla::WorkDir;
use strict;
use warnings;
use utf8;
use Path::Tiny;
use Archive::Tar;
use File::pushd;
use Data::Dumper; # serializer
use File::Spec::Functions qw(splitdir);
use File::Basename qw(dirname);
use Data::Section::Simple qw(get_data_section);

use Minilla::Util qw(randstr);
use Minilla::CPANMeta;
use Minilla::FileGatherer;

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

has [qw(prereq_specs verifier)] => (
    is => 'lazy',
);

no Moo;

{
    our $INSTANCE;
    sub instance {
        my ($class, $c) = @_;
        $INSTANCE ||= Minilla::WorkDir->new(
            base_dir => $c->base_dir,
            c => $c,
        );
    }
}

sub DEMOLISH {
    my $self = shift;
    unless ($self->c->debug) {
        path(path($self->dir)->dirname)->remove_tree({safe => 0});
    }
}

sub _build_verifier {
    my $self = shift;

    my $verifier = Minilla::PrereqVerifier->new(
        base_dir     => $self->base_dir,
        c            => $self->c,
        auto_install => $self->c->auto_install,
    );
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

    my @files = Minilla::FileGatherer->gather_files(
        $self->c->base_dir
    );
    \@files;
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

sub build {
    my ($self) = @_;

    return if $self->{build}++;

    my $guard = pushd($self->dir);

    # Generate meta file
    {
        my $meta = Minilla::CPANMeta->new(
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

    $self->c->infof("Writing MANIFEST file\n");
    {
        path('MANIFEST')->spew(join("\n", @files));
    }
}

sub dist_test {
    my $self = shift;

    $self->build();

    $self->verifier->verify([qw(runtime)], $_) for qw(requires recommends);
    $self->verifier->verify([qw(test)], $_) for qw(requires recommends);

    {
        local $ENV{RELEASE_TESTING} = 1;
        $self->c->cmd('prove', '-r', '-l', 't', (-d 'xt' ? 'xt' : ()));
    }
}

sub dist {
    my ($self) = @_;

    $self->{tarball} ||= do {
        my $c = $self->c;

        $self->build();

        my $guard = pushd($self->dir);

        # Create tar ball
        my $tarball = sprintf('%s-%s.tar.gz', $self->c->config->name, $self->c->config->version);

        my $tar = Archive::Tar->new;
        for (@{$self->files}, qw(Build.PL LICENSE META.json META.yml MANIFEST)) {
            $tar->add_data(path($self->c->config->{name} . '-' . $self->c->config->{version}, $_), path($_)->slurp);
        }
        $tar->write(path($self->c->base_dir, $tarball), COMPRESS_GZIP);
        $self->c->infof("Wrote %s\n", $tarball);

        $tarball;
    };
}

sub write_release_tests {
    my $self = shift;

    my $guard = pushd($self->dir);
    path('xt')->mkpath;

    my $name = $self->c->config->name;
    for my $file (qw(
        xt/minimum_version.t
        xt/cpan_meta.t
        xt/pod.t
        xt/spelling.t
    )) {
        my $content = get_data_section($file);
        $content =~s!<<DIST>>!$name!g;
        path($file)->spew($content);
    }
}

1;
__DATA__

@@ xt/minimum_version.t
use Test::More;
eval "use Test::MinimumVersion 0.101080";
plan skip_all => "Test::MinimumVersion required for testing perl minimum version" if $@;
all_minimum_version_from_metayml_ok();

@@ xt/cpan_meta.t
use Test::More;
eval "use Test::CPAN::Meta";
plan skip_all => "Test::CPAN::Meta required for testing META.yml" if $@;
plan skip_all => "There is no META.yml" unless -f "META.yml";
meta_yaml_ok();

@@ xt/pod.t
use strict;
use Test::More;
eval "use Test::Pod 1.41";
plan skip_all => "Test::Pod 1.41 required for testing POD" if $@;
all_pod_files_ok();

@@ xt/spelling.t
use strict;
use Test::More;
use File::Spec;
eval q{ use Test::Spelling };
plan skip_all => "Test::Spelling is not installed." if $@;
eval q{ use Pod::Wordlist::hanekomu };
plan skip_all => "Pod::Wordlist::hanekomu is not installed." if $@;

plan skip_all => "no ENV[HOME]" unless $ENV{HOME};
plan skip_all => "no ~/.aspell.en.pws" unless -e File::Spec->catfile($ENV{HOME}, '.aspell.en.pws');

add_stopwords('<<DIST>>');

$ENV{LANG} = 'C';
my $has_aspell;
foreach my $path (split(/:/, $ENV{PATH})) {
    -x "$path/aspell" and $has_aspell++, last;
}
plan skip_all => "no aspell" unless $has_aspell;
plan skip_all => "no english dict for aspell" unless `aspell dump dicts` =~ /en/;

set_spell_cmd('aspell list -l en');
all_pod_files_spelling_ok('lib');
