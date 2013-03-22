# NAME

Minilla - CPAN module authoring tool

# SYNOPSIS

    minil new     - Create new dist
    minil test    - Run test cases
    minil dist    - Make tar ball
    minil install - Install dist to your system
    minil release - Release dist to CPAN

# DESCRIPTION

Minilla is CPAN module authoring tool.

    (M::I - inc) + shipit + (dzil - plugins)

__THIS IS A DEVELOPMENT RELEASE. API MAY CHANGE WITHOUT NOTICE__.

# FEATURES

# TODO

    # TODO: --trial

# FAQ

- Why don't you provide plugin support?

    If you want to pluggable thing, it's already exist dzil :P

- How can I specify custom homepage in META?

    You can set 'homepage' key in your minil.toml file.

- Should I add (META.json|Build.PL) to repository?

    Yes. You need to add it for git installable repo.

- How do I manage ppport.h?

    Is there a reason to remove ppport.h from repo?

- How can I install script files?

    Your executables must be in `script/`. It's [Module::Build::Tiny](http://search.cpan.org/perldoc?Module::Build::Tiny)'s rule.

- Why minil only supports git?

    I think git is a best VC for CPAN modules, for now.

    If you want to use another version control system, you can use [Moth](http://search.cpan.org/perldoc?Moth).

- HOW TO SWITCH FROM M::I/M::B?

    You can use experimental \`minil migrate\` command.
    Please look [Minilla::CLI::Migrate](http://search.cpan.org/perldoc?Minilla::CLI::Migrate).

# AUTHOR

Tokuhiro Matsuno <tokuhirom AAJKLFJEF@ gmail.com>

# SEE ALSO

# LICENSE

Copyright (C) Tokuhiro Matsuno

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
