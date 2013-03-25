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

This subcommand migrate existed distribution repository to minil ready repository.

=head1 HOW IT WORKS

This module runs script like following shell script.

    # Generate META.json from Module::Build or EU::MM

    # Create cpanfile from META.json

    # Switch to M::B::Tiny for git instllable repo.
    echo 'use Module::Build::Tiny; Build_PL()' > Build.PL

    # MANIFEST, MANIFEST.SKIP is no longer needed.
    git rm MANIFEST MANIFEST.SKIP

    # generate META.json
    minil meta

    # remove META.json from ignored file list
    perl -i -pe 's!^META.json\n$!!' .gitignore
    echo '.build/' >> .gitignore

    # remove .shipit if it's exists.
    if [ -f '.shipit' ]; then git rm .shipit; fi

    # add things
    git add .

    # And commit to repo!
    git commit -m 'minil!'

