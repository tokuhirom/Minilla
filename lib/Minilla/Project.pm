package Minilla::Project;
use strict;
use warnings;
use utf8;

use TOML qw(from_toml);
use File::Basename qw(basename dirname);
use File::Spec::Functions qw(catdir catfile);
use Path::Tiny;
use DirHandle;
use File::pushd;

use Minilla::Logger;
use Minilla::Metadata;
use Minilla::Util qw(slurp_utf8 find_dir);

use Moo;

has c => (
    is => 'rw',
    required => 1,
);

has dir => (
    is => 'rw',
    builder => 1,
    trigger => 1,
    required => 1,
);

has dist_name => (
    is => 'lazy',
);

has main_module_path => (
    is => 'lazy',
);

has metadata => (
    is => 'lazy',
    required => 1,
    handles => [qw(name abstract version perl_version author license)],
    clearer => 1,
);

no Moo;

sub _build_dir {
    my $self = shift;

    my $gitdir = find_dir('.git')
        or $self->c->error(sprintf("Current directory is not in git(%s)", Cwd::getcwd()));
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
            $self->c->error("TOML error in $toml_path: $err");
        }
        $conf;
    } else {
        +{};
    }
}

sub homepage { shift->config->{homepage} }

sub _build_dist_name {
    my $self = shift;
    my $c = $self->c;

    my $dist_name;
    if (my $conf = $self->config) {
        $dist_name = $conf->{name};
    }
    unless (defined $dist_name) {
        $c->infof("There is no minil.toml. Detecting project name from directory name.\n");
        $dist_name = do {
            local $_ = basename($self->dir);
            $_ =~ s!\Ap5-!!;
            $_;
        };
    }
    if ($dist_name eq '.') { Carp::confess("Heh? " . $self->dir); }

    unless ($dist_name) {
        $c->errorf("Cannot detect distribution name from minil.toml or directory name(cwd: %s, dir:%s)\n", Cwd::getcwd(), $self->dir);
    }

    return $dist_name;
}

sub _build_main_module_path {
    my $self = shift;
    my $c = $self->c;

    my $dist_name = $self->dist_name;
    my $source_path = $self->_detect_source_path($dist_name);
    unless (defined($source_path) && -e $source_path) {
        $c->error(sprintf("%s not found.\n", $source_path || "main module($dist_name)"));
    }

    $c->infof("Retrieving meta data from %s.\n", $source_path);
    return $source_path;
}

sub _build_metadata {
    my $self = shift;
    my $c = $self->c;

    # fill from main_module
    my $metadata = Minilla::Metadata->new(
        source => $self->main_module_path,
    );
    $c->infof("Name: %s\n", $metadata->name);
    $c->infof("Abstract: %s\n", $metadata->abstract);
    $c->infof("Version: %s\n", $metadata->version);

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

    for my $path ("App-$dir", $dir) {
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

    my $dat = {
        "meta-spec" => {
            "version" => "2",
            "url"     => "http://search.cpan.org/perldoc?CPAN::Meta::Spec"
        },
        license        => $self->license->meta2_name,
        abstract       => $self->abstract,
        author         => [ $self->author ],
        dynamic_config => 0,
        version        => $self->version,
        name           => $self->dist_name,
        prereqs        => $cpanfile->prereq_specs,
        generated_by   => "Minilla/$Minilla::VERSION",
        release_status => $release_status || 'stable',
    };

    # fill 'provides' section
    if ($release_status ne 'unstable') {
        $dat->{provides} = Module::Metadata->provides(
            dir     => File::Spec->catdir($self, 'lib'),
            version => 2
        );
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
                $http_url =~ s!\.git$!/tree!;
                $dat->{resources}->{repository} = +{
                    url => $git_url,
                };
                $dat->{resources}->{homepage} = $self->homepage || $http_url;
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
    $parser->parse_from_file($self->main_module_path);

    my $fname = File::Spec->catfile($self->dir, 'README.md');
    open my $fh, '>', $fname
        or $self->errorf("%s: %s\n", $fname, $!);
    print $fh $parser->as_markdown;
    close $fh or die "$!\n";
}

sub verify_prereqs {
    my ($self, $phases, $type) = @_;

    if (eval q{require CPAN::Meta::Check; 1;}) { ## no critic
        my $cpanfile = $self->load_cpanfile();
        my @err = CPAN::Meta::Check::verify_dependencies($cpanfile->prereqs, $phases, $type);
        for (@err) {
            if (/Module '([^']+)' is not installed/ && $self->c->auto_install) {
                my $module = $1;
                $self->c->print("Installing $module\n");
                $self->c->cmd('cpanm', $module)
            } else {
                $self->c->print("Warning: $_\n", ERROR);
            }
        }
    }
}

sub work_dir {
    my $self = shift;

    my $work_dir = Minilla::WorkDir->new(
        c        => $self->c,
        project  => $self,
    );
}

1;

