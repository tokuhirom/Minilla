package Minilla::CLI::Bumpversion;
use strict;
use warnings;
use utf8;

use Minilla::Util qw(find_file);

sub run {
    my ($self, @args) = @_;
    my $type = shift @args || 'default';

    my $dry_run;
    $self->parse_options(
        \@args,
        'dry-run!' => \$dry_run,
    );

    my @opts;
    push @opts, +{
        'default' => '-bump',
        'major'   => '-bump-revision',
        'minor'   => '-bump-version',
        'patch'   => '-bump-subversion',
    }->{$type} || '-bump';
    if ($dry_run) {
        push @opts, '-dryrun';
    }
    $self->cmd('perl-reversion', @opts);

    unless ($dry_run) {
        my $project = Minilla::Project->load(
            c => $self,
        );
        my $newver = $project->metadata->version;
        if (exists_tagged_version($newver)) {
            $self->error("Sorry, version '$newver' is already tagged.  Stopping.\n");
        }
    }
}

sub exists_tagged_version {
    my ( $ver ) = @_;

    my $x       = `git tag -l $ver`;
    chomp $x;
    return !!$x;
}

1;
__END__

=head1 NAME

Minilla::CLI::Bumpversion - bump up version in all perl scripts in project

=head1 SYNOPSIS

    # bump up patch version
    % minil bumpversion
    # or 
    % minil bumpversion patch

    # bump up minor version
    % minil bumpversion minor

    # bump up major version
    % minil bumpversion major

=head1 DESCRIPTION

Bump up versions in perl modules.

