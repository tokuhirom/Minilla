package Minilla::FileGatherer;
use strict;
use warnings;
use utf8;
use File::pushd;
use Path::Tiny;

sub gather_files {
    my ($self, $root) = @_;
    my $guard = pushd($root);
    my @files = map { path($_)->relative($root) } split /\n/, `git ls-files`;
}

1;
