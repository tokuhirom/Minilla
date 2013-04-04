package Minilla::Migrate;
use strict;
use warnings;
use utf8;

use File::pushd;
use CPAN::Meta;
use Path::Tiny;
use File::Find ();
use TOML qw(to_toml);
use Config;

use Minilla::Gitignore;
use Minilla::Util qw(slurp spew require_optional cmd slurp_utf8 spew_utf8 slurp_raw spew_raw);
use Minilla::Logger;
use Minilla::Git;
use Minilla::Project;

use Moo;

has project => (
    is => 'lazy',
);

no Moo;

sub _build_project {
    my $self = shift;
    Minilla::Project->new();
}

sub run {
    my $self = shift;

    my $guard = pushd($self->project->dir);

    # Generate cpanfile from Build.PL/Makefile.PL
    unless (-f 'cpanfile') {
        $self->migrate_cpanfile();
    }

    $self->generate_license();

    # TODO move top level *.pm to lib/?

    if (-f 'dist.ini') {
        $self->dist_ini2minil_toml();
    }

    $self->remove_unused_files();
    $self->migrate_gitignore();
    $self->project->regenerate_files();
    $self->migrate_changes();

    git_add('.');
}

sub migrate_changes {
    my $self = shift;
    
    if (-f 'Changes') {
        # Q. Why :raw?
        # A. It's for windows. See dzil.
        my $content = slurp_raw('Changes');
        unless ($content =~ qr!\{\{\$NEXT\}\}!) {
            $content =~ s!^(Revision history for Perl extension \S+\n\n)!$1\{\{\$NEXT\}\}\n\n!;
        }
        spew_raw('Changes', $content);
    } else {
        # Q. Why :raw?
        # A. It's for windows. See dzil.
        require Minilla::Profile::Default;
        Minilla::Profile::Default->new_from_project(
            $self->project
        )->render('Changes');
    }
}

sub rm {
    my ($self, $file) = @_;
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
        git_add('minil.toml');
    }
    git_rm('--quiet', 'dist.ini');

    $self->project->clear_metadata();
}

sub generate_license {
    my ($self) = @_;

    unless (-f 'LICENSE') {
        spew_raw('LICENSE', $self->project->metadata->license->fulltext());
        git_add(qw(LICENSE));
    }
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
        cmd($Config{make}, 'metafile');
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

    infof("Using Module::Build (Because this distribution uses xs)\n");
    delete $prereqs->{configure}->{requires}->{'ExtUtils::MakeMaker'};
    delete $prereqs->{configure}->{requires}->{'Module::Build'};
    delete $prereqs->{configure}->{requires}->{'Module::Build::Tiny'};

    my $cpanfile = Module::CPANfile->from_prereqs($prereqs);
    spew('cpanfile', $cpanfile->to_string);

    git_add('cpanfile');
}

sub remove_unused_files {
    my $self = shift;

    # Some users put a README.pod symlink for main module.
    # But it's duplicated to README.md created by Minilla.

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
        MANIFEST.SKIP.bak
        MANIFEST.bak
        README.pod
        META.yml
        README
        MYMETA.json
        MYMETA.yml
        inc/Module/Install.pm
    ), glob('inc/Module/Install/*.pm')) {
        if (-e $file) {
            if (grep { $_ eq $file } git_ls_files()) {
                # committed file
                git_rm('--quiet', $file);
            } else {
                unlink $file;
            }
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

    git_add(qw(.gitignore));
}



1;

