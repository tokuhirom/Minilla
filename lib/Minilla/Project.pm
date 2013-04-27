package Minilla::Project;
use strict;
use warnings;
use utf8;

use TOML 0.92 qw(from_toml);
use File::Basename qw(basename dirname);
use File::Spec::Functions qw(catdir catfile);
use Path::Tiny;
use DirHandle;
use File::pushd;
use CPAN::Meta;
use Module::CPANfile;

use Minilla;
use Minilla::Logger;
use Minilla::Metadata;
use Minilla::WorkDir;
use Minilla::ReleaseTest;
use Minilla::ModuleMaker::ModuleBuild;
use Minilla::Util qw(slurp_utf8 find_dir cmd spew_raw slurp_raw);

use Moo;

has dir => (
    is => 'rw',
    builder => 1,
    trigger => 1,
    required => 1,
);

has module_maker => (
    is => 'ro',
    default => sub { Minilla::ModuleMaker::ModuleBuild->new() },
);

has dist_name => (
    is => 'lazy',
);

has build_class => (
    is => 'lazy',
);

has main_module_path => (
    is => 'lazy',
);

has metadata => (
    is => 'lazy',
    required => 1,
    handles => [qw(name perl_version license)],
    clearer => 1,
);

has contributors => (
    is => 'lazy',
);

has work_dir => (
    is => 'lazy',
);

has files => (
    is => 'lazy',
);

has no_index => (
    is => 'ro',
    default => sub {
        {
            directory => [qw(
                t xt inc share eg examples author
            ) ]
        }
    },
);

no Moo;

sub version {
    my $self = shift;
    $self->config->{version} || $self->metadata->version;
}

sub authors {
    my $self = shift;
    if (my $authors_from = $self->config->{authors_from}) {
        my $meta = Minilla::Metadata->new(
            source => $authors_from
        );
        return $meta->authors;
    }
    $self->config->{authors} || $self->metadata->authors;
} 

sub abstract {
    my $self = shift;
    if (my $abstract_from = $self->config->{abstract_from}) {
        my $meta = Minilla::Metadata->new(
            source => $abstract_from
        );
        return $meta->abstract;
    }
    $self->config->{abstract} || $self->metadata->abstract;
} 

sub _build_dir {
    my $self = shift;

    my $gitdir = find_dir('.git')
        or errorf("Current directory is not in git(%s)", Cwd::getcwd());
    $gitdir = File::Spec->rel2abs($gitdir);
    my $base_dir = dirname($gitdir);

    return $base_dir;
}

sub _trigger_dir {
    my ($self, $dir) = @_;
    unless (File::Spec->file_name_is_absolute($dir)) {
        $self->dir(File::Spec->rel2abs($dir));
    }
}

sub config {
    my $self = shift;

    my $toml_path = path($self->dir, 'minil.toml');
    if (-f $toml_path) {
        my ($conf, $err) = from_toml(slurp_utf8($toml_path));
        if ($err) {
            errorf("TOML error in %s: %s\n", $toml_path, $err);
        }
        $conf;
    } else {
        +{};
    }
}

sub _build_dist_name {
    my $self = shift;

    my $dist_name;
    if (my $conf = $self->config) {
        $dist_name = $conf->{name};
    }
    unless (defined $dist_name) {
        infof("Detecting project name from directory name.\n");
        $dist_name = do {
            local $_ = basename($self->dir);
            $_ =~ s!\Ap5-!!;
            $_;
        };
    }
    if ($dist_name eq '.') { Carp::confess("Heh? " . $self->dir); }

    unless ($dist_name) {
        errorf("Cannot detect distribution name from minil.toml or directory name(cwd: %s, dir:%s)\n", Cwd::getcwd(), $self->dir);
    }

    return $dist_name;
}

sub _build_build_class {
    my $self = shift;

    my $build_class;
    if (my $conf = $self->config) {
        $build_class = $conf->{build}{build_class};
    }

    return $build_class || 'Module::Build';
}

sub _build_main_module_path {
    my $self = shift;

    my $dist_name = $self->dist_name;
    my $source_path = $self->_detect_source_path($dist_name);
    unless (defined($source_path) && -e $source_path) {
        errorf("%s not found.\n", $source_path || "main module($dist_name)");
    }

    infof("Retrieving meta data from %s.\n", $source_path);
    return $source_path;
}

sub _build_metadata {
    my $self = shift;

    my $config = +{%{$self->config}};
    if (my $license = delete $config->{license}) {
        $config->{_license_name} = $license;
    }

    # fill from main_module
    my $metadata = Minilla::Metadata->new(
        source => $self->main_module_path,
        %$config,
    );
    infof("Name: %s\n", $metadata->name);
    infof("Abstract: %s\n", $metadata->abstract);
    infof("Version: %s\n", $metadata->version);

    return $metadata;
}

sub _case_insensitive_match {
    my $path = shift;
    my @path = File::Spec->splitdir($path);
    my $realpath = '.';
    LOOP: for my $part (@path) {
        my $d = DirHandle->new($realpath)
            or do {
            # warn "Cannot open dirhandle";
            return;
        };
        while (defined($_ = $d->read)) {
            if (uc($_) eq uc($part)) {
                $realpath = catfile($realpath, $_);
                next LOOP;
            }
        }

        # does not match
        # warn "Does not match: $part in $realpath";
        return undef;
    }
    return $realpath;
}

sub _detect_source_path {
    my ($self, $dir) = @_;

    # like cpan-outdated => lib/App/cpanminus.pm
    my $pat2 = "App-" . do {
        local $_ = $dir;
        s!-!!;
        $_;
    };
    for my $path ("App-$dir", $pat2, $dir) {
        $path =~ s!::!/!g;
        $path =~ s!-!/!g;
        $path = "lib/${path}.pm";

        return $path if -f $path;

        $path = _case_insensitive_match($path);
        return $path if defined($path);
    }

    return undef;
}

sub load_cpanfile {
    my $self = shift;
    Module::CPANfile->load(catfile($self->dir, 'cpanfile'));
}

sub cpan_meta {
    my ($self, $release_status) = @_;
    $release_status ||= 'stable';

    my $cpanfile = $self->load_cpanfile;
    my $merged_prereqs = $cpanfile->prereqs->with_merged_prereqs(
        CPAN::Meta::Prereqs->new($self->module_maker->prereqs)
    );
    $merged_prereqs = $merged_prereqs->with_merged_prereqs(
        CPAN::Meta::Prereqs->new(Minilla::ReleaseTest->prereqs)
    );
    if ($self->metadata->perl_version) {
        $merged_prereqs = $merged_prereqs->with_merged_prereqs(
            CPAN::Meta::Prereqs->new(+{
                runtime => {
                    requires => {
                        perl => $self->metadata->perl_version,
                    }
                }
            })
        );
    }
    $merged_prereqs = $merged_prereqs->as_string_hash;

    my $dat = {
        "meta-spec" => {
            "version" => "2",
            "url"     => "http://search.cpan.org/perldoc?CPAN::Meta::Spec"
        },
        license        => $self->license->meta2_name,
        abstract       => $self->abstract,
        dynamic_config => 0,
        version        => $self->version,
        name           => $self->dist_name,
        prereqs        => $merged_prereqs,
        generated_by   => "Minilla/$Minilla::VERSION",
        release_status => $release_status || 'stable',
        no_index       => $self->no_index,
    };
    unless ($dat->{abstract}) {
        errorf("Cannot retrieve 'abstract' from %s\n", $self->dir);
    }
    if ($self->authors) {
        $dat->{author} = $self->authors;
    } else {
        errorf("Cannot determine 'author' from %s\n", $self->dir);
    }
    if ($self->contributors && @{$self->contributors} > 0) {
        $dat->{x_contributors} = $self->contributors;
    }

    # fill 'provides' section
    if ($release_status ne 'unstable') {
        my $provides = Module::Metadata->provides(
            dir     => File::Spec->catdir($self->dir, 'lib'),
            version => 2
        );
        unless (%$provides) {
            errorf("%s does not provides any package. Abort.\n", $self->dir);
        }
        $dat->{provides} = $provides;
    }

    # fill repository information
    {
        my $guard = pushd($self->dir);
        if ( `git remote show -n origin` =~ /URL: (.*)$/m && $1 ne 'origin' ) {
            # XXX Make it public clone URL, but this only works with github
            my $git_url = $1;
            $git_url =~ s![\w\-]+\@([^:]+):!git://$1/!;
            if ($git_url =~ /github\.com/) {
                my $http_url = $git_url;
                $http_url =~ s![\w\-]+\@([^:]+):!https://$1/!;
                $http_url =~ s!\Agit://!https://!;
                $http_url =~ s!\.git$!!;
                unless ($self->config->{no_github_issues}) {
                    $dat->{resources}->{bugtracker} = +{
                        web => "$http_url/issues",
                    };
                }
                $dat->{resources}->{repository} = +{
                    url => $git_url,
                    web => $http_url,
                };
                $dat->{resources}->{homepage} = $self->config->{homepage} || $http_url;
            } else {
                # normal repository
                $dat->{resources}->{repository} = +{
                    url => $git_url,
                };
            }
        }
    }

    my $meta = CPAN::Meta->new($dat);
    return $meta;
}

sub readme_from {
    my $self = shift;
    $self->config->{readme_from} || $self->main_module_path;
}

sub regenerate_files {
    my $self = shift;

    $self->regenerate_meta_json();
    $self->regenerate_readme_md();
    $self->module_maker->generate($self);
}

sub regenerate_meta_json {
    my $self = shift;

    my $meta = $self->cpan_meta('unstable');
    $meta->save(File::Spec->catfile($self->dir, 'META.json'), {
        version => '2.0'
    });
}

sub regenerate_readme_md {
    my $self = shift;

    require Pod::Markdown;

    my $parser = Pod::Markdown->new;
    $parser->parse_from_file($self->readme_from);

    my $fname = File::Spec->catfile($self->dir, 'README.md');
    spew_raw($fname, $parser->as_markdown);
}

sub verify_prereqs {
    my ($self, $phases, $type) = @_;

    if ($Minilla::AUTO_INSTALL) {
        system('cpanm', '--quiet', '--installdeps', '--with-develop', '.');
    }
}

sub _build_contributors {
    my $self = shift;

    my $normalize = sub {
        local $_ = shift;
        if (/<([^>]+)>/) {
            $1;
        } else {
            $_;
        }
    };
    my @lines = do {
        my %uniq;
        reverse grep { !$uniq{$normalize->($_)}++ } split /\n/, `git log --format="%aN <%aE>"`
    };
    my %is_author = map { $normalize->($_) => 1 } @{$self->authors};
    @lines = grep { !$is_author{$normalize->($_)} } @lines;
    @lines = grep { $_ ne 'Your Name <you@example.com>' } @lines;
    \@lines;
}

sub _build_work_dir {
    my $self = shift;
    Minilla::WorkDir->new(
        project  => $self,
    );
}

sub _build_files {
    my $self = shift;
    my $conf = $self->config->{'FileGatherer'};
    my @files = Minilla::FileGatherer->new(
        exclude_match => $conf->{exclude_match},
        exists $conf->{include_dotfiles} ? (include_dotfiles => $conf->{include_dotfiles}) : (),
    )->gather_files(
        $self->dir
    );
    \@files;
}

sub perl_files {
    my $self = shift;
    my @files = @{$self->files};
    grep {
        $_ =~ /\.(?:pm|pl|t)$/i || slurp_raw($_) =~ m{ ^ \#\! .* perl }ix
    } @files;
}

1;

