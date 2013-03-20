package Minya::CLI::Test;
use strict;
use warnings;
use utf8;
use Module::CPANfile;
use File::pushd;

sub run {
    my ($self, @args) = @_;

    $self->parse_options(
        \@args,
    );

    my $work_dir = Minya::WorkDir->new(dir => $self->work_dir);
    $work_dir->setup($self);
    $self->verify_dependencies([qw(develop test runtime)], $_) for qw(requires recommends);

    my $guard = pushd($work_dir->dir);
    $self->cmd($self->config->{test_command} || 'prove -l -r t ' . (-d 'xt' ? 'xt' : ''));
}

1;

