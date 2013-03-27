package Minilla::FileGatherer;
use strict;
use warnings;
use utf8;
use File::pushd;
use File::Spec;

use Minilla::Git;

use Moo;

has exclude_match => (
    is => 'ro',
    default => sub { +[ ] },
);

no Moo;

sub gather_files {
    my ($self, $root) = @_;
    my $guard = pushd($root);
    my @files = grep { not -l $_ } map { File::Spec->abs2rel($_, $root) } git_ls_files();
    if ($self->exclude_match) {
        for my $pattern (@{$self->exclude_match || []}) {
            @files = grep { $_ !~ $pattern } @files;
        }
    }
    return @files;
}

1;
