package Minilla::CLI::Migrate;
use strict;
use warnings;
use utf8;
use File::pushd;
use CPAN::Meta;
use Path::Tiny;
use File::Find::Rule;

use Minilla::Util qw(slurp spew);

sub run {
    my ($self, @args) = @_;

    my $base = pushd($self->base_dir());

    my $tiny = (0+(File::Find::Rule->file()->name(qr/\.(c|xs)$/)->in('.')) == 0);

    # Generate cpanfile from Build.PL
    unless (-f 'cpanfile') {
        _migrate_cpanfile($self, $tiny);
    }

    _generate_license($self);
    _generate_build_pl($self, $tiny);

    _remove_unused_files($self);
    _migrate_gitignore($self);
    _migrate_meta_json($self);
}

sub _generate_license {
    my $self = shift;

    unless (-f 'LICENSE') {
        path('LICENSE')->spew($self->config->metadata->license->fulltext());
    }
}

sub _migrate_cpanfile {
    my ($self, $tiny) = @_;

    if (-f 'Build.PL') {
        if (slurp('Build.PL') =~ /Module::Build::Tiny/) {
            $self->infof("M::B::Tiny was detected. I hope META.json is already exists here\n");
        } else {
            $self->cmd($^X, 'Build.PL');
            $self->cmd($^X, 'Build', 'distmeta');
        }
    } elsif (-f 'Makefile.PL') {
        $self->cmd($^X, 'Makefile.PL');
        $self->cmd('make metafile');
    } else {
        $self->error("There is no Build.PL/Makefile.PL");
    }

    unless (-f 'META.json') {
        $self->error("Cannot generate META.json\n");
    }

    my $meta = CPAN::Meta->load_file('META.json');
    my $prereqs = $meta->effective_prereqs->as_string_hash;

    if ($tiny) {
        delete $prereqs->{configure}->{runtime}->{'Module::Build'};
        $prereqs->{configure}->{runtime}->{'Module::Build::Tiny'} = 0;
    } else {
        $prereqs->{configure}->{runtime}->{'Module::Build'}    = 0.40;
        $prereqs->{configure}->{runtime}->{'Module::CPANfile'} = 0;
    }

    my $ret = '';
    for my $phase (qw(runtime configure build develop)) {
        my $indent = $phase eq 'runtime' ? '' : '    ';
        $ret .= "on $phase => sub {\n" unless $phase eq 'runtime';
        for my $type (qw(requires recommends)) {
            while (my ($k, $version) = each %{$prereqs->{$phase}->{$type}}) {
                $ret .= "${indent}$type '$k' => '$version';\n";
            }
        }
        $ret .= "};\n\n" unless $phase eq 'runtime';
    }
    spew('cpanfile', $ret);

    $self->cmd('git add cpanfile');
}

sub _generate_build_pl {
    my ($self, $tiny) = @_;
    if ($tiny) {
        path('Build.PL')->spew("use Module::Build::Tiny;\nBuild_PL()");
    } else {
        my $dist = path($self->base_dir)->basename;
           $dist =~ s/^p5-//;
        (my $module = $dist) =~ s!-!::!g;
        path('Build.PL')->spew(Minilla::Skeleton->render_build_mb_pl({
            dist   => $dist,
            module => $module,
        }));
    }
}

sub _remove_unused_files {
    my $self = shift;

    # remove some unusable files
    for my $file (qw(
        Makefile.PL
        MANIFEST
        MANIFEST.SKIP
        .shipit
        xt/97_podspell.t
        xt/99_pod.t
    )) {
        if (-f $file) {
            $self->cmd("git rm $file");
        }
    }
}

sub _migrate_meta_json {
    my $self = shift;

    my $cpanfile = Module::CPANfile->load('cpanfile');
    Minilla::CPANMeta->new(
        config       => $self->config,
        prereq_specs => $cpanfile->prereq_specs,
        base_dir     => $self->base_dir,
    )->generate('unstable')->save(
        'META.json' => {
            version => 2.0
        }
    );
}

sub _migrate_gitignore {
    my $self = shift;

    my @lines;
    
    if (-f '.gitignore') {
        @lines = path('.gitignore')->lines({chomp => 1});
    }

    # remove META.json from ignored file list
        @lines = grep !/^META\.json$/, @lines;

    # Add some lines
    for my $fname (qw(
        .build
        _build_params
        /Build
        !Build/
        !META.json
    )) {
        unless (grep /\A$fname\z/, @lines) {
            push @lines, $fname;
        }
    }

    path('.gitignore')->spew(join('', map { "$_\n" } @lines));
}

1;
__END__

=head1 NAME

Minilla::CLI::Migrate - Migrate existed distribution repo

=head1 SYNOPSIS

    % minil migrate

=head1 DESCRIPTION

This subcommand migrate existed distribution repository to minil ready repository.

=head1 HOW IT WORKS

This module runs script like following shell script.

    # Generate META.json from Module::Build or EU::MM

    # Create cpanfile from META.json

    # Switch to M::B::Tiny for git instllable repo.
    echo 'use Module::Build::Tiny; Build_PL()' > Build.PL

    # MANIFEST, MANIFEST.SKIP is no longer needed.
    git rm MANIFEST MANIFEST.SKIP

    # generate META.json
    minil meta

    # remove META.json from ignored file list
    perl -i -pe 's!^META.json\n$!!' .gitignore
    echo '.build/' >> .gitignore

    # remove .shipit if it's exists.
    if [ -f '.shipit' ]; then git rm .shipit; fi

    # add things
    git add .

    # And commit to repo!
    git commit -m 'minil!'

