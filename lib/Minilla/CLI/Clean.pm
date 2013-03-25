package Minilla::CLI::Clean;
use strict;
use warnings;
use utf8;
use ExtUtils::MakeMaker qw(prompt);
use File::Path qw(rmtree);

use Minilla::Project;

sub run {
    my $self = shift;

    my $project = Minilla::Project->new();
    my @targets = grep { -e $_ } (
        glob(sprintf("%s-*", $project->dist_name)),
        'blib',
        'Build',
        'MYMETA.json',
        'MYMETA.yml',
        '_build_params',
    );
    print("Would remove $_\n") for (@targets);
    if (prompt('Remove it?', 'y') =~ /y/i) {
        rmtree($_) for @targets;
    }
}

1;
__END__

=head1 NAME

Minilla::CLI::Clean - Clean up directory

=head1 SYNOPSIS

    % minil clean

=head1 DESCRIPTION

Remove some temporary files.

