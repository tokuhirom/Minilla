package Minilla;
use strict;
use warnings;
use 5.008005;
our $VERSION = '0.0.36';

1;
__END__

=encoding utf8

=head1 NAME

Minilla - CPAN module authoring tool

=head1 SYNOPSIS

    minil new     - Create new dist
    minil test    - Run test cases
    minil dist    - Make tar ball
    minil install - Install dist to your system

=head1 DESCRIPTION

Minilla is CPAN module authoring tool.

    (M::I - inc) + shipit + (dzil - plugins)

B<THIS IS A DEVELOPMENT RELEASE. API MAY CHANGE WITHOUT NOTICE>.

=head1 FEATURES

=over 4

=back

=head1 TODO

    'provides' section in meta
    # TODO: --trial

=head1 HOW TO SWITCH FROM M::I/M::B?

(I will add `minil migrate` but not implemented yet.)

    # Switch to M::B::Tiny for git instllable repo.
    echo 'use Module::Build::Tiny; Build_PL()' > Build.PL

    # MANIFEST, MANIFEST.SKIP is no longer needed.
    git add MANIFEST MANIFEST.SKIP

    # generate META.json
    minil meta

    # remove META.json from ignored file list
    perl -i -pe 's!^META.json\n$!!' .gitignore
    echo '.build/' >> .gitignore

    # remove .shipit
    if [ -f '.shipit' ]; then git rm .shipit; fi

    # add things
    git add .

    # And commit to repo!
    git commit -m 'minil!'

=head1 FAQ

=over 4

=item Why don't you provide plugin support?

If you want to pluggable thing, it's already exist dzil :P

=item How can I specify custom homepage in META?

You can set 'homepage' key in your minil.toml file.

=item Should I add (META.json|Build.PL) to repository?

Yes. You need to add it for git installable repo.

=item How do I manage ppport.h?

Is there a reason to remove ppport.h from repo?

=back

=head1 AUTHOR

Tokuhiro Matsuno E<lt>tokuhirom AAJKLFJEF@ GMAIL COME<gt>

=head1 SEE ALSO

=head1 LICENSE

Copyright (C) Tokuhiro Matsuno

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
