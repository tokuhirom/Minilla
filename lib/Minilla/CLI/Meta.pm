package Minilla::CLI::Meta;
use strict;
use warnings;
use utf8;
use Path::Tiny;
use Minilla::CPANMeta;
use Module::CPANfile;
use Minilla::Util qw(find_file);
use File::pushd;
use File::Spec::Functions qw(catfile);

sub run {
    my ($self, @args) = @_;

    $self->parse_options(
        \@args,
    );

    my $guard = pushd($self->base_dir);

    my $cpanfile = Module::CPANfile->load('cpanfile');
    my $meta = Minilla::CPANMeta->new(
        config       => $self->config,
        prereq_specs => $cpanfile->prereq_specs,
        base_dir     => $self->base_dir,
    )->generate('unstable');
    $meta->save('META.json', {
        version => '2.0'
    });
}

1;
__END__

=head1 NAME

Minilla::CLI::Meta - Regenerate META.json

=head1 SYNOPSIS

    % minil meta

=head1 DESCRIPTION

This module generate META.json file from the repository.

