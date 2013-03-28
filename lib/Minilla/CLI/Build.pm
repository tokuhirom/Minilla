package Minilla::CLI::Build;
use strict;
use warnings;
use utf8;

use Path::Tiny;
use File::Copy::Recursive qw(rcopy);

use Minilla::Project;
use Minilla::Logger;
use Minilla::Util qw(parse_options);

sub run {
    my ($self, @args) = @_;

    my $test = 1;
    parse_options(
        \@args,
        'test!' => \$test,
    );

    my $project = Minilla::Project->new();
    $project->regenerate_files();

    # generate project directory
    my $work_dir = $project->work_dir;
    $work_dir->build();

    my $dst = sprintf("%s-%s", $project->dist_name, $project->version);
    infof("Copying %s to %s\n", $work_dir->dir, $dst);
    path($dst)->remove_tree();
    rcopy($work_dir->dir => $dst)
        or errorf("%s\n", $!);
}

1;
__END__

=head1 NAME

Minilla::CLI::Build - Build dist directory

=head1 SYNOPSIS

    % minil build

=head1 DESCRIPTION

TBD
