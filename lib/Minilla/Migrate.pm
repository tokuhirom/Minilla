package Minilla::Migrate;
use strict;
use warnings;
use utf8;

use File::pushd;
use CPAN::Meta;
use Path::Tiny;
use File::Find::Rule;
use TOML qw(to_toml);

use Minilla::Util qw(slurp spew require_optional);

use Moo;

has c => (
    is => 'ro',
    required => 1,
);

has use_mb_tiny => (
    is => 'lazy',
);

has project => (
    is => 'lazy',
);

no Moo;

sub _build_project {
    my $self = shift;

    Minilla::Project->new(
        c => $self->c,
    );
}

sub _build_use_mb_tiny {
    my $self = shift;
    (0+(File::Find::Rule->file()->name(qr/\.(c|xs)$/)->in('.')) == 0);
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
        $self->c->cmd('git mv bin script');
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

    $self->c->infof("Converting dist.ini to minil.toml\n");

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
    my $toml = to_toml($dst);
    spew( 'minil.toml' => $toml );
    $self->git_add('minil.toml');
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
    $self->c->cmd(qw(git rm), @files);
}

sub git_add {
    my ($self, @files) = @_;
    $self->c->cmd(qw(git add), @files);
}

sub migrate_cpanfile {
    my ($self) = @_;

    my $metafile;
    if (-f 'Build.PL') {
        if (slurp('Build.PL') =~ /Module::Build::Tiny/) {
            $self->c->infof("M::B::Tiny was detected. I hope META.json is already exists here\n");
            $metafile = 'META.json';
        } else {
            $self->c->cmd($^X, 'Build.PL');
            $metafile = 'MYMETA.json';
        }
    } elsif (-f 'Makefile.PL') {
        $self->c->cmd($^X, 'Makefile.PL');
        $self->c->cmd('make metafile');
        $metafile = 'MYMETA.json';
    } elsif (-f 'dist.ini') {
        my %orig = map { $_ => 1 } glob('*/META.yml');
        $self->c->cmd('dzil build');
        ($metafile) = grep { !$orig{$_} } glob('*/META.yml');
    } else {
        $self->c->errorf("There is no Build.PL/Makefile.PL/dist.ini: %s\n", Cwd::getcwd());
    }

    unless (defined($metafile) && -f $metafile) {
        $self->c->error("Build.PL/Makefile.PL does not generates $metafile\n");
    }

    my $meta = CPAN::Meta->load_file($metafile);
    my $prereqs = $meta->effective_prereqs->as_string_hash;

    if ($self->use_mb_tiny) {
        $self->c->infof("Using Module::Build::Tiny\n");
        delete $prereqs->{configure}->{requires}->{'Module::Build'};
        delete $prereqs->{configure}->{requires}->{'ExtUtils::MakeMaker'};
        $prereqs->{configure}->{requires}->{'Module::Build::Tiny'} = 0;
    } else {
        $self->c->infof("Using Module::Build (Because this distribution uses xs)\n");
        delete $prereqs->{configure}->{requires}->{'ExtUtils::MakeMaker'};
        $prereqs->{configure}->{requires}->{'Module::Build'}    = 0.40;
        $prereqs->{configure}->{requires}->{'Module::CPANfile'} = 0;
    }

    my $cpanfile = Module::CPANfile->from_prereqs($prereqs);
    spew('cpanfile', $cpanfile->to_string);

    $self->c->cmd('git add cpanfile');
}

sub generate_build_pl {
    my ($self) = @_;

    if ($self->use_mb_tiny) {
        path('Build.PL')->spew("use Module::Build::Tiny;\nBuild_PL();\n");
    } else {
        my $dist = path($self->project->dir)->basename;
           $dist =~ s/^p5-//;
        (my $module = $dist) =~ s!-!::!g;
        path('Build.PL')->spew(Minilla::Skeleton->render_build_mb_pl({
            dist   => $dist,
            module => $module,
        }));
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
            $self->c->cmd("git rm $file");
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
    
    if (-f '.gitignore') {
        @lines = path('.gitignore')->lines({chomp => 1});
    }

    # remove META.json from ignored file list
        @lines = grep !/^META\.json$/, @lines;

    my $tarpattern = sprintf('/%s-*', $self->project->dist_name);
    # Add some lines
    for my $fname (qw(
        /.build
        /_build_params
        /Build
        !Build/
        !META.json
    ), $tarpattern) {
        unless (grep /\A\Q$fname\E\z/, @lines) {
            push @lines, $fname;
        }
    }

    path('.gitignore')->spew(join('', map { "$_\n" } @lines));

    $self->git_add(qw(.gitignore));
}



1;

