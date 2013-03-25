package Minilla;
use strict;
use warnings;
use 5.008005;
use version; our $VERSION = version->declare("v0.0.46");

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
    minil release - Release dist to CPAN

=head1 DESCRIPTION

Minilla is CPAN module authoring tool.

    (M::I - inc) + shipit + (dzil - plugins)

B<THIS IS A DEVELOPMENT RELEASE. API MAY CHANGE WITHOUT NOTICE>.

=head1 FEATURES

=over 4

=back

=head1 TODO

    # TODO: --trial

=head1 CONFIGURATION

Minilla uses B<Convention over Configuration>.

But, you can write configurations to I<minil.toml> file by L<TOML|https://github.com/mojombo/toml>.

=over 4

=item name

You can write 'name' instead of detecting project name from directory name.

=item no_github_issues

Minilla sets bugtracker as github issues by default. But if you want to use RT, you can set this variable.

=back

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

=item How can I install script files?

Your executables must be in F<script/>. It's L<Module::Build::Tiny>'s rule.

=item Why minil only supports git?

I think git is a best VC for CPAN modules, for now.

If you want to use another version control system, you can use L<Moth>.

=item HOW TO SWITCH FROM M::I/M::B?

You can use experimental `minil migrate` command.
Please look L<Minilla::CLI::Migrate>.

=back

=head1 AUTHOR

Tokuhiro Matsuno E<lt> tokuhirom @ gmail.com E<gt>

=head1 SEE ALSO

=head1 LICENSE

Copyright (C) Tokuhiro Matsuno

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
