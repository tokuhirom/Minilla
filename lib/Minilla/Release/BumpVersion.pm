package Minilla::Release::BumpVersion;
use strict;
use warnings;
use utf8;
use ExtUtils::MakeMaker qw(prompt);

use Minilla::Util qw(find_file require_optional cmd);
use Minilla::Logger;
use Module::BumpVersion;
use version ();

sub init {
    require_optional(
        'Module/BumpVersion.pm', 'Release engineering'
    );
    require_optional(
        'Version/Next.pm', 'Release engineering'
    );
}

sub run {
    my ($self, $project, $opts) = @_;

    if (my $ver = prompt("Next Release?", $self->default_new_version($project))) {
        # Do not use is_strict. is_strict rejects '5.00_01' style.
        if (!version::is_lax($ver)) {
            errorf("Sorry, version '%s' is invalid.  Stopping.\n", $ver);
        }

        my @opts;
        push @opts, '-set', $ver;
        if ($opts->{dry_run}) {
            push @opts, '-dryrun';
        }
        unless ($opts->{dry_run}) {
            $self->bump_version($project, $ver);

            # clear old version information
            $project->clear_metadata();
            my $newver = $project->metadata->version;
            if (exists_tag($project->format_tag($newver))) {
                errorf("Sorry, version '%s' is already tagged.  Stopping.\n", $newver);
            }
        }
    }
}

sub bump_version {
    my ($self, $project, $version) = @_;

    for my $file ($project->perl_files) {
        next if $file =~ /\.t$/;
        next if $file =~ m{\Ashare/};

        my $bump = Module::BumpVersion->load($file);
        $bump->set_version($version);
    }
}

sub default_new_version {
    my ($self, $project) = @_;
    @_==2 or die;

    my $curver = $project->metadata->version;
    if (not exists_tag($project->format_tag($curver))) {
        $curver;
    } else {
        # $project->metadata->version returns version.pm object.
        # But stringify was needed by Version::Next.
        return Version::Next::next_version("$curver");
    }
}

sub exists_tag {
    my ( $tag ) = @_;

    my $x       = `git tag -l $tag`;
    chomp $x;
    return !!$x;
}

1;


