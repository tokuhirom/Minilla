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

        my $curr_ver = $project->metadata->version;
        if (!check_version_compatibility($curr_ver, $ver)) {
            my $msg = sprintf
                "version: %s\n" .
                "current: %s\n" .
                "The version format doesn't match the current one.\n" .
                "Continue the release with this version? [y/n]", $ver, $curr_ver;
            if (prompt($msg) !~ /y/i) {
                errorf("Stop the release due to version format mismatch\n");
            }
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

        next if $file eq 'Makefile.PL' || $file eq 'Build.PL';
        # copy from Menlo::CLI::Compat
        next if grep { $file =~ m!^$_/! } @{$project->no_index->{directory} || []};
        next if grep { $file eq $_ } @{$project->no_index->{file} || []};

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

sub check_version_compatibility {
    my ($curr, $next) = @_;

    return version_format($curr) eq version_format($next)
}

sub version_format {
    local $_ = shift;
    # All formats accept an optional alpha notation starting with '_'.
    return
        # ex. 0.11, 3.14, 9.4_1
        /^(?:0|[1-9][0-9]*)\.[0-9]+(?:_[0-9]+)?$/           ? 'decimal'    :
        # ex. v1.2.3, v1.2.3_4, v3.3, v3.4_5
        /^v(?:0|[1-9][0-9]*)(?:\.[0-9]+){1,2}(?:_[0-9]+)?$/ ? 'dotted'     :
        # ex. 0.1.2, 3.4.5_67 (to distinguish it from the decimal version, it must have exactly two dots)
        /^(?:0|[1-9][0-9]*)(?:\.[0-9]+){2}(?:_[0-9]+)?$/    ? 'lax dotted' :
                                                              'unknown';
}

sub exists_tag {
    my ( $tag ) = @_;

    my $x       = `git tag -l $tag`;
    chomp $x;
    return !!$x;
}

1;
