package Minilla::CLI::Build;
use strict;
use warnings;
use utf8;

use Minilla::Project;
use Path::Tiny;
use File::Copy::Recursive qw(rcopy);

sub run {
    my ($self, @args) = @_;

    my $test = 1;
    $self->parse_options(
        \@args,
        'test!' => \$test,
    );

    my $project = Minilla::Project->new(
        c => $self
    );

    # update META.json
    $project->regenerate_meta_json();

    # generate README.md
    $project->regenerate_readme_md();

    # generate project directory
    my $work_dir = $project->work_dir;
    $work_dir->build();

    my $dst = sprintf("%s-%s", $project->dist_name, $project->version);
    $self->infof("Copying %s to %s\n", $work_dir->dir, $dst);
    path($dst)->remove_tree();
    rcopy($work_dir->dir => $dst)
        or $self->error("$!\n");
}

1;
__END__

=head1 NAME

Minilla::CLI::Build - Build dist dir

=head1 SYNOPSIS

    % minil build

=head1 DESCRIPTION

TBD
