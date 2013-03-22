package Minilla::CLI::Test;
use strict;
use warnings;
use utf8;
use Module::CPANfile;
use File::pushd;
use Minilla::WorkDir;
use Minilla::PrereqVerifier;

sub run {
    my ($self, @args) = @_;

    $self->parse_options(
        \@args,
    );

    my $work_dir = Minilla::WorkDir->new(
        c        => $self,
        base_dir => $self->base_dir
    );

    my $verifier = Minilla::PrereqVerifier->new(
        base_dir => $self->base_dir,
        auto_install => $self->auto_install,
        c => $self,
    );
    $verifier->verify( [qw(develop test runtime)], $_ ) for qw(requires recommends);

    my $guard = pushd($work_dir->dir);
    $self->cmd($self->config->{test_command} || 'prove -l -r t ' . (-d 'xt' ? 'xt' : ''));
}

1;
__END__

=head1 NAME

Minilla::CLI::Test - Run test cases

=head1 SYNOPSIS

    % minil test

=head1 DESCRIPTION

This subcommand run test cases.

