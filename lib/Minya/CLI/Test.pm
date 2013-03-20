package Minya::CLI::Test;
use strict;
use warnings;
use utf8;
use Module::CPANfile;

sub run {
    my ($class, $c, @args) = @_;

    $c->parse_options(
        \@args,
    );

    my $config = $c->config;

    my $guard = $c->setup_workdir();
    $c->verify_dependencies([qw(test runtime)], $_) for qw(requires recommends);
    $c->cmd($config->{test_command} || 'prove -l -r t ' . (-d 'xt' ? 'xt' : ''));
}

1;

