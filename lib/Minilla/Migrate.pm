package Minilla::Migrate;
use strict;
use warnings;
use utf8;

use File::pushd;
use CPAN::Meta;
use Path::Tiny;
use File::Find ();
use TOML qw(to_toml);

use Minilla::Gitignore;
use Minilla::Util qw(slurp spew require_optional cmd);
use Minilla::Logger;
use Minilla::Profile::Default;

use Moo;

has use_mb_tiny => (
    is => 'lazy',
);

has project => (
    is => 'lazy',
);

no Moo;

sub _build_project {
    my $self = shift;
    Minilla::Project->new();
}

sub _build_use_mb_tiny {
    my $self = shift;
    my $xs_found = 0;
    File::Find::find(
        {
            wanted => sub {
                $xs_found++ if /\.(xs|c)$/
            },
            no_chdir => 1,
        }, '.'
    );
    $xs_found;
}

sub run {
    my $self = shift;

    my $guard = pushd($self->project->dir);

    # Generate cpanfile from Build.PL
    unless (-f 'cpanfile') {
        $self->migrate_cpanfile();
    }

    $self->generate_license();
    $self->generate_build_pl();

    # M::B::Tiny protocol
    if (-d 'bin' && !-e 'script') {
        cmd('git mv bin script');
    }
    # TODO move top level *.pm to lib/?

    if (-f 'dist.ini') {
        $self->dist_ini2minil_toml();
    }

    $self->remove_unused_files();
    $self->migrate_gitignore();
    $self->project->regenerate_meta_json();
    $self->project->regenerate_readme_md();
    $self->git_add(qw(META.json README.md));
}

sub dist_ini2minil_toml {
    my $self = shift;

    infof("Converting dist.ini to minil.toml\n");

    require_optional( 'Config/MVP/Reader/INI.pm', 'Migrate dzil repo' );
    require_optional( 'Dist/Zilla/MVP/Assembler.pm', 'Migrate dzil repo' );
    require_optional( 'Dist/Zilla/Chrome/Term.pm', 'Migrate dzil repo' );
    my $sequence = Config::MVP::Reader::INI->read_into_assembler(
        'dist.ini',
        Dist::Zilla::MVP::Assembler->new(
            chrome => Dist::Zilla::Chrome::Term->new(),
        )
    );
    my $conf = do {
        # Note. dist.ini using @Milla does not have '_' section.
        my $section = $sequence->section_named('_');
        $section ? $section->payload : +{};
    };

    my $dst = +{};
    for my $key (qw(name author version license)) {
        if ( defined(my $val = $conf->{$key}) ) {
            $dst->{$key} = $val;
        }
    }
    if (%$dst) {
        my $toml = to_toml($dst);
        spew( 'minil.toml' => $toml );
        $self->git_add('minil.toml');
    }
    $self->git_rm('dist.ini');

    $self->project->clear_metadata();
}

sub generate_license {
    my ($self) = @_;

    unless (-f 'LICENSE') {
        path('LICENSE')->spew($self->project->metadata->license->fulltext());
        $self->git_add(qw(LICENSE));
    }
}

sub git_rm {
    my ($self, @files) = @_;
    cmd(qw(git rm -f), @files);
}

sub git_add {
    my ($self, @files) = @_;
    cmd(qw(git add), @files);
}

sub migrate_cpanfile {
    my ($self) = @_;

    my $metafile;
    if (-f 'Build.PL') {
        if (slurp('Build.PL') =~ /Module::Build::Tiny/) {
            infof("M::B::Tiny was detected. I hope META.json is already exists here\n");
            $metafile = 'META.json';
        } else {
            cmd($^X, 'Build.PL');
            $metafile = 'MYMETA.json';
        }
    } elsif (-f 'Makefile.PL') {
        cmd($^X, 'Makefile.PL');
        cmd('make metafile');
        $metafile = 'MYMETA.json';
    } elsif (-f 'dist.ini') {
        my %orig = map { $_ => 1 } glob('*/META.yml');
        cmd('dzil build');
        ($metafile) = grep { !$orig{$_} } glob('*/META.yml');
    } else {
        errorf("There is no Build.PL/Makefile.PL/dist.ini: %s\n", Cwd::getcwd());
    }

    unless (defined($metafile) && -f $metafile) {
        errorf("Build.PL/Makefile.PL does not generates %s\n", $metafile);
    }

    my $meta = CPAN::Meta->load_file($metafile);
    my $prereqs = $meta->effective_prereqs->as_string_hash;

    if ($self->use_mb_tiny) {
        infof("Using Module::Build::Tiny\n");
        delete $prereqs->{configure}->{requires}->{'Module::Build'};
        delete $prereqs->{configure}->{requires}->{'ExtUtils::MakeMaker'};
        $prereqs->{configure}->{requires}->{'Module::Build::Tiny'} = 0;
    } else {
        infof("Using Module::Build (Because this distribution uses xs)\n");
        delete $prereqs->{configure}->{requires}->{'ExtUtils::MakeMaker'};
        $prereqs->{configure}->{requires}->{'Module::Build'}    = 0.40;
        $prereqs->{configure}->{requires}->{'Module::CPANfile'} = 0;
    }

    my $cpanfile = Module::CPANfile->from_prereqs($prereqs);
    spew('cpanfile', $cpanfile->to_string);

    $self->git_add('cpanfile');
}

sub generate_build_pl {
    my ($self) = @_;

    if ($self->use_mb_tiny) {
        path('Build.PL')->spew("use 5.008001;\nuse Module::Build::Tiny;\nBuild_PL();\n");
    } else {
        my $dist = path($self->project->dir)->basename;
           $dist =~ s/^p5-//;
        (my $module = $dist) =~ s!-!::!g;
        require Minilla::Profile::XS;
        Minilla::Profile::XS->render(
            'Build.PL', 'Build.PL', {
                dist   => $dist,
                module => $module,
            }
        );
    }

    $self->git_add(qw(Build.PL));
}

sub remove_unused_files {
    my $self = shift;

    # remove some unusable files
    for my $file (qw(
        Makefile.PL
        MANIFEST
        MANIFEST.SKIP
        .shipit
        xt/97_podspell.t
        xt/99_pod.t
        xt/01_podspell.t    xt/03_pod.t              xt/05_cpan_meta.t
        xt/04_minimum_version.t  xt/06_meta_author.t
    )) {
        if (-f $file) {
            cmd("git rm $file");
        }
    }

    for my $file (qw(
        MANIFEST.SKIP.bak
        MANIFEST.bak
    )) {
        if (-f $file) {
            path($file)->remove;
        }
    }
}

sub migrate_gitignore {
    my ($self) = @_;

    my @lines;

    my $gitignore = (
        -f '.gitignore'
        ? Minilla::Gitignore->load('.gitignore')
        : Minilla::Gitignore->new()
    );
    $gitignore->remove('META.json');
    $gitignore->remove('/META.json');

    # Add some lines
    $gitignore->add(sprintf('/%s-*', $self->project->dist_name));
    for my $fname (qw(
        /.build
        /_build_params
        /Build
        !Build/
        !META.json
    )) {
        $gitignore->add($fname);
    }

    $gitignore->save('.gitignore');

    $self->git_add(qw(.gitignore));
}



1;

