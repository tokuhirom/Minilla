# NAME

Minilla - CPAN module authoring tool

# SYNOPSIS

    minil new     - Create a new dist
    minil test    - Run test cases
    minil dist    - Make your dist tarball
    minil install - Install your dist
    minil release - Release your dist to CPAN

# DESCRIPTION

Minilla is a CPAN module authoring tool. Minilla provides [minil](http://search.cpan.org/perldoc?minil) command for authorizing a CPAN distribution.

    (M::I - inc) + shipit + (dzil - plugins)

__THIS IS A DEVELOPMENT RELEASE. API MAY CHANGE WITHOUT NOTICE__.

# MOTIVATION

# CONVENTION

As stated above, Minilla is opinionated. Minilla has a bold assumption and convention like the followings, which are almost compatible to the sister project [Dist::Milla](http://search.cpan.org/perldoc?Dist::Milla).

- Your module written in Pure Perl are located in _lib/_.
- Your executable file is in _script/_ directory, if any
- Your module is maintained with __Git__ and `git ls-files` matches with what you will release
- Your module has a static list of prerequisites that can be described in [cpanfile](http://search.cpan.org/perldoc?cpanfile)
- Your module has a Changes file

# GETTING STARTED

    # First time only
    % cpanm Minilla
    # Minilla has only a few deps. It should be very quick

    # Make a new distribution
    % minil new Dist-Name
    % cd Dist-Name/

    # Git commit
    % git commit -m "initial commit"

    # Hack your code!
    % $EDITOR lib/Dist/Name.pm t/dist-name.t cpanfile

    # Done? Test and release it!
    % minil release

It's that easy.

You already have distributions with [Module::Install](http://search.cpan.org/perldoc?Module::Install), [Module::Build](http://search.cpan.org/perldoc?Module::Build), [Dist::Zilla](http://search.cpan.org/perldoc?Dist::Zilla) or [ShipIt](http://search.cpan.org/perldoc?ShipIt)? Migrating is also trivial. See "MIGRATING" in [Minilla::Tutorial](http://search.cpan.org/perldoc?Minilla::Tutorial) for more details.

# WHY MINILLA?

## Repository managed by Minilla is git install ready.

The repository created and managed by Minilla is git install ready.
You can install the library by `cpanm git://...`.

Of course, you can install Minilla from `cpanm git://github.com/tokuhirom/Minilla.git`.

## Minilla is built on small libraries.

Minilla is built on only few small libraries. You can install Minilla without a huge list of dependencies to heavy modules.

## And, what is Minilla?

    Minilla is a Kaiju (Japanese giant monster) from the Godzilla series of films and is the first of several young Godzillas.
    http://en.wikipedia.org/wiki/Minilla

# CONFIGURATION

Minilla uses __Convention over Configuration__.

But, you can write configurations to _minil.toml_ file in [TOML](https://github.com/mojombo/toml) format. Minilla reads the _minil.toml_ file in the root directory of your project.

- name

    You can write 'name' instead of automatically detecting project name out of the directory name.

- readme\_from

        readme_from="lib/My/Foo.pod"

    You can specify the file to generate the README.md. This is a main module path by default.

- abstract\_from

        abstract_from="lib/My/Foo.pod"

    Grab abstract information from the file contains pod.

- authors\_from

        authors_from="lib/My/Foo.pod"

    Grab authors information from the file contains pod.

- allow\_pure\_perl

        allow_pure_perl=1

    A bool indicating the module is still functional without its XS parts.  When an XS module is build
    with `--pureperl_only`, it will otherwise fail.

    It affects to [Module::Build](http://search.cpan.org/perldoc?Module::Build) 0.4005+ only.

- no\_github\_issues

        no_github_issues=true

    Minilla sets bugtracker as github issues by default. But if you want to use RT, you can set this variable.

- no\_index

        [no_index]
        directory=['t', 'xt', 'tools']

    Minilla sets META.json's no\_index as `directory => ['t', 'xt', 'inc', 'share', 'eg', 'examples', 'author']`
    by default. But if you want to change them, you can set this section variable. If this section is set,
    specified variables are only used, in fact default settings are not merged.

- script\_files

        script_files = ['bin/foo', 'script/*']

    Minilla sets install script files as `['script/*', 'bin/*']` by default.

- build.build\_class

    Specify a custom Module::Build subclass.

        [build]
        build_class = builder::MyBuilder

# FAQ

- Why don't you provide plug-in support?

    If you want to pluggable thing, it's already exist dzil :P
    And if you like a behavior like Minilla, you can use [Dist::Milla](http://search.cpan.org/perldoc?Dist::Milla), the sister project of Minilla.
    [Dist::Milla](http://search.cpan.org/perldoc?Dist::Milla)'s behavior is mostly like Minilla.

- Why minil only supports git?

    I think git is a best VC for CPAN modules, for now.

    If you want to use another version control system, you can probably use [Dist::Milla](http://search.cpan.org/perldoc?Dist::Milla).

- And why...

    Yes. You can use [Dist::Milla](http://search.cpan.org/perldoc?Dist::Milla).

- Should I add (META.json|Build.PL) to repository?

    Yes. You need to add it to make your git repo installable via cpanm.

- How do I manage ppport.h?

    Is there a reason to remove ppport.h from repo?

- How can I install script files?

    Your executables must be in `script/`. It's [Module::Build::Tiny](http://search.cpan.org/perldoc?Module::Build::Tiny)'s rule.

- How to switch from Module::Install/Module::Build/Dist::Zilla?

    You can use experimental \`minil migrate\` sub-command.
    See [Minilla::CLI::Migrate](http://search.cpan.org/perldoc?Minilla::CLI::Migrate) for more details.

# AUTHORS

Tokuhiro Matsuno < tokuhirom@gmail.com >

Tatsuhiko Miyagawa

# THANKS TO

RJBS, the author of [Dist::Zilla](http://search.cpan.org/perldoc?Dist::Zilla). [Dist::Zilla](http://search.cpan.org/perldoc?Dist::Zilla) points CPAN authorizing tool.

# SEE ALSO

# LICENSE

Copyright (C) Tokuhiro Matsuno

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
