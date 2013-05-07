package Minilla::CLI::Dist;
use strict;
use warnings;
use utf8;

use File::Spec::Functions qw(catfile);
use File::Basename qw(basename);
use File::Copy qw(copy);

use Minilla::Project;
use Minilla::Util qw(parse_options);

sub run {
    my ($self, @args) = @_;

    my $test = 1;
    parse_options(
        \@args,
        'test!' => \$test,
    );

    my $project = Minilla::Project->new();
    my $work_dir = $project->work_dir;
    if ($test) {
        local $ENV{RELEASE_TESTING} = 1;
        $work_dir->dist_test();
    }
    my $tar = $work_dir->dist();
    my $dst = catfile($project->dir, basename($tar));
    copy($tar, $dst);
}

1;
__END__

=head1 NAME

Minilla::CLI::Dist - Make tar ball distribution

=head1 SYNOPSIS

    % minil dist

=head1 DESCRIPTION

This sub-command makes distribution tar ball.

