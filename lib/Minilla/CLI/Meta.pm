package Minilla::CLI::Meta;
use strict;
use warnings;
use utf8;
use Minilla::Project;

sub run {
    my ($self, @args) = @_;

    $self->parse_options(
        \@args,
    );

    my $meta = Minilla::Project->new(
        c => $self,
    )->cpan_meta('unstable');
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

