package Minilla::Release::BumpVersion;
use strict;
use warnings;
use utf8;
use ExtUtils::MakeMaker qw(prompt);

use Minilla::Util qw(find_file require_optional cmd);
use Minilla::Logger;
use Dist::BumpVersion;

sub init {
    require_optional(
        'Dist/BumpVersion.pm', 'Release engineering'
    );
}

sub run {
    my ($self, $project, $opts) = @_;

    if (my $ver = prompt("Next Release?", $self->default_new_version($project))) {
        my @opts;
        push @opts, '-set', $ver;
        if ($opts->{dry_run}) {
            push @opts, '-dryrun';
        }
        unless ($opts->{dry_run}) {
            my $bump = Dist::BumpVersion->new($project->dir);
            $bump->bump_version()
                or die $bump->errstr;

            # clear old version information
            $project->clear_metadata();
            my $newver = $project->metadata->version;
            if (exists_tagged_version($newver)) {
                errorf("Sorry, version '%s' is already tagged.  Stopping.\n", $newver);
            }
        }
    }
}

sub default_new_version {
    my ($self, $project) = @_;
    @_==2 or die;

    my $curver = $project->metadata->version;
    if (not exists_tagged_version($curver)) {
        $curver;
    } else {
        my $version = Perl::Version->new( $curver );
        if ($version->is_alpha) {
            $version->inc_alpha;
        } else {
            my $pos = $version->components-1;
            $version->increment($pos);
        }
        $version;
    }
}

sub exists_tagged_version {
    my ( $ver ) = @_;

    my $x       = `git tag -l $ver`;
    chomp $x;
    return !!$x;
}

1;


