package Minilla::CLI::Migrate;
use strict;
use warnings;
use utf8;

use Minilla::Util qw(slurp spew);
use Minilla::Migrate;

sub run {
    my ($self, @args) = @_;
    Minilla::Migrate->new()->run;
}

1;
__END__

=head1 NAME

Minilla::CLI::Migrate - Migrate existed distribution repo

=head1 SYNOPSIS

    % minil migrate

=head1 DESCRIPTION

This sub-command migrate existed distribution repository to minil ready repository.

=head1 HOW IT WORKS

This module runs script like following shell script.

    # Generate META.json from Module::Build or EU::MM
    perl Build.PL

    # Create cpanfile from META.json
    mymeta-cpanfile > cpanfile

    # MANIFEST, MANIFEST.SKIP is no longer needed.
    git rm MANIFEST MANIFEST.SKIP

    # generate META.json
    minil build
    git add -f META.json

    # remove META.json from ignored file list
    perl -i -pe 's!^META.json\n$!!' .gitignore
    echo '.build/' >> .gitignore

    # remove .shipit if it's exists.
    if [ -f '.shipit' ]; then git rm .shipit; fi

    # add things
    git add .

