package Minilla::CLI::Build;
use strict;
use warnings;
use utf8;

use File::Path qw(rmtree mkpath);
use File::Spec;

use Minilla::Project;
use Minilla::WorkDir;
use Minilla::Logger;
use Minilla::Util qw(parse_options);

sub run {
    my ($class, @args) = @_;

    my $test = 1;
    parse_options(
        \@args,
        'test!' => \$test,
    );

    my $project = Minilla::Project->new();
    $project->regenerate_files();

    my $dst = File::Spec->rel2abs(sprintf("%s-%s", $project->dist_name, $project->version));

    # generate project directory
    infof("Create %s\n", $dst);
    rmtree($dst);
    mkpath($dst);
    my $work_dir = Minilla::WorkDir->new(project => $project, dir => $dst, cleanup => 0);
    $work_dir->build();
}

1;
__END__

=head1 NAME

Minilla::CLI::Build - Build dist directory

=head1 SYNOPSIS

    % minil build

=head1 DESCRIPTION

TBD
