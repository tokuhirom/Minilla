package Minya::CLI::Test;
use strict;
use warnings;
use utf8;
use Module::CPANfile;

sub run {
    my ($self, @args) = @_;

    $self->parse_options(
        \@args,
    );

    my $guard = $self->setup_workdir();
    $self->verify_dependencies([qw(develop test runtime)], $_) for qw(requires recommends);
    $self->cmd($self->config->{test_command} || 'prove -l -r t ' . (-d 'xt' ? 'xt' : ''));
}

1;

