package Minilla::Release::BumpVersion;
use strict;
use warnings;
use utf8;
use ExtUtils::MakeMaker qw(prompt);

use Minilla::Util qw(find_file require_optional cmd);
use Minilla::Logger;

sub init {
    require_optional(
        'Perl/Version.pm', 'Release engineering'
    );
}

sub run {
    my ($self, $project, $opts) = @_;

    my $curver = $project->metadata->version;

    # Note: perl-revision command is included in Perl::Version.
    if (exists_tagged_version($curver)) {
        my $default_newver = do {
            my $version = Perl::Version->new( $curver );
            if ($version->is_alpha) {
                $version->inc_alpha;
            } else {
                my $pos = $version->components-1;
                $version->increment($pos);
            }
            $version;
        };
        if (my $ver = prompt("Next Release?", $default_newver)) {
            my @opts;
            push @opts, '-set', $ver;
            if ($opts->{dry_run}) {
                push @opts, '-dryrun';
            }
            unless ($opts->{dry_run}) {
                cmd('perl-reversion', @opts);

                # clear old version information
                $project->clear_metadata();
                my $newver = $project->metadata->version;
                if (exists_tagged_version($newver)) {
                    errorf("Sorry, version '%s' is already tagged.  Stopping.\n", $newver);
                }
            }
        }
    } else {
        infof('Skipped bump up');
    }
}

sub exists_tagged_version {
    my ( $ver ) = @_;

    my $x       = `git tag -l $ver`;
    chomp $x;
    return !!$x;
}

1;


