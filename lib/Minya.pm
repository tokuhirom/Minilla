package Minya;
use strict;
use warnings;
use 5.008005;
our $VERSION = '0.0.36';

1;
__END__

=encoding utf8

=head1 NAME

Minya - CPAN module authoring tool

=head1 SYNOPSIS

    minya new     - Create new dist
    minya setup   - Setup global config
    minya test    - Run test cases
    minya dist    - Make tar ball
    minya install - Install dist to your system

=head1 DESCRIPTION

Minya is CPAN module authoring tool.

    (M::I - inc) + shipit + (dzil - plugins)

B<THIS IS A DEVELOPMENT RELEASE. API MAY CHANGE WITHOUT NOTICE>.

=head1 FEATURES

=over 4

=back

=head1 TODO

    'provides' section in meta
    # TODO: --trial

=head1 FAQ

=over 4

=item Why don't you provide plugin support?

If you want to pluggable thing, it's already exist dzil :P

=item How can I specify custom homepage in META?

You can set 'homepage' key in your minya.toml file.

=back

=head1 AUTHOR

Tokuhiro Matsuno E<lt>tokuhirom AAJKLFJEF@ GMAIL COME<gt>

=head1 SEE ALSO

=head1 LICENSE

Copyright (C) Tokuhiro Matsuno

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
