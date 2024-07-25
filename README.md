[![Actions Status](https://github.com/tokuhirom/Minilla/actions/workflows/test.yml/badge.svg)](https://github.com/tokuhirom/Minilla/actions) [![MetaCPAN Release](https://badge.fury.io/pl/Minilla.svg)](https://metacpan.org/release/Minilla)
# NAME

Minilla - CPAN module authoring tool

# SYNOPSIS

    minil new     - Create a new dist
    minil test    - Run test cases
    minil dist    - Make your dist tarball
    minil install - Install your dist
    minil release - Release your dist to CPAN
    minil run     - Run arbitrary commands against build dir

# DESCRIPTION

Minilla is a CPAN module authoring tool. Minilla provides [minil](https://metacpan.org/pod/minil) command for authorizing a CPAN distribution.

    (M::I - inc) + shipit + (dzil - plugins)

# CONVENTION

As stated above, Minilla is opinionated. Minilla has a bold assumption and convention like the followings, which are almost compatible to the sister project [Dist::Milla](https://metacpan.org/pod/Dist%3A%3AMilla).

- Your modules are written in Pure Perl and are located in _lib/_.
- Your executable files are in _script/_ directory, if any
- Your module is maintained with **Git**, `git ls-files` matches with what you will release and your remote is named _origin_
- Your module has a static list of prerequisites that can be described in [cpanfile](https://metacpan.org/pod/cpanfile)
- Your module has a Changes file
- Your module requires at least perl 5.6.

# GETTING STARTED

    # First time only
    % cpanm --with-recommends Minilla
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

You already have distributions with [Module::Install](https://metacpan.org/pod/Module%3A%3AInstall), [Module::Build](https://metacpan.org/pod/Module%3A%3ABuild), [Dist::Zilla](https://metacpan.org/pod/Dist%3A%3AZilla) or [ShipIt](https://metacpan.org/pod/ShipIt)? Migrating is also trivial. See "MIGRATING" in [Minilla::Tutorial](https://metacpan.org/pod/Minilla%3A%3ATutorial) for more details.

# WHY MINILLA?

## Repository managed by Minilla is git install ready.

The repository created and managed by Minilla is git install ready.
You can install the library by `cpanm git://...`.

Of course, you can install Minilla from `cpanm git://github.com/tokuhirom/Minilla.git`.

## Minilla is built on small libraries.

Minilla is built on only few small libraries. You can install Minilla without a huge list of dependencies to heavy modules.

## And, what is Minilla?

    Minilla is a Kaiju (Japanese giant monster) from the Godzilla series of films and is the first of several young Godzillas.
    https://en.wikipedia.org/wiki/Minilla

# Minilla's release process

Minilla's release process is the following.

## CheckUntrackedFiles

Checking git's untracked files. If there's untracked files, minilla will abort.

## CheckOrigin

This step will run the \`git remote\`. If there's no remote, minilla will abort.

## CheckReleaseBranch

Checking git's current branch is \`release.branch\` key in minil.toml. If no match, minilla will abort.

## BumpVersion

Minilla will show 'Next Release?' prompt. You can input next version number.

After that, minilla rewrites version numbers in \*\*/\*.pm, \*\*/\*.pl, and a script file contains perl-ish shebang.

## CheckChanges

You need to write Changes file. Your module's users need to know the difference between versions.

Minilla's Changes file includes \`{{$NEXT}}\` next version indicator. You should put update informations after that.

## RegenerateFiles

In this step, minilla will regenerate META.json, README.md and (Makefile.PL|Build.PL).

## RunHooks

This step runs commands listed on \`release.hooks\` key in minil.toml.

## DistTest

This script runs test cases in clean working directory with `$ENV{RELEASE_TESTING} = 1`.

## MakeDist

Make distribution tar ball.

## UploadToCPAN

Upload your module to CPAN.

## RewriteChanges

Rewrite Changes file.
Minilla replaces `{{$NEXT}}` with released version number and current date & time.
And put `{{$NEXT}}` on the first line.

## Commit

Commit current directory with automatically generated commit message from Changes file. And push it to origin.

## Tag

Create new git tag and push it to origin.

# CONFIGURATION

Minilla uses **Convention over Configuration**.

But, you can write configurations to _minil.toml_ file in [TOML](https://github.com/toml-lang/toml) format. Minilla reads the _minil.toml_ file in the root directory of your project.

- name

    You can write 'name' instead of automatically detecting project name out of the directory name.

- module\_maker

    Minilla supports three module building mechanisms. Module::Build::Tiny is the default one and Module::Build or ExtUtils::MakeMaker are the alternatives. See also [FAQ](#faq) section in this document.

        module_maker="ModuleBuild"

- readme\_from

        readme_from="lib/My/Foo.pod"

    You can specify the file to generate the README.md. This is a main module path by default.

- tag\_format

        tag_format="perl/%v"

    format of the tag to apply. Defaults to %v. `%v` will replace with the distribution version.

- abstract\_from

        abstract_from="lib/My/Foo.pod"

    Grab abstract information from the file contains pod.

- authors\_from

        authors_from="lib/My/Foo.pod"

    Grab authors information from the file contains pod.

- authority

        authority = "cpan:TOKUHIROM"

    Set x\_authority attribute to META.
    See [https://jawnsy.wordpress.com/2011/02/20/what-is-x\_authority/](https://jawnsy.wordpress.com/2011/02/20/what-is-x_authority/) for more details.
    Note that now PAUSE itself copies the permissions from the "main module"
    to any new modules entering the index for the first time,
    so you don't need to set this attribute anymore.

- allow\_pureperl

        allow_pureperl=1

    A boolean indicating the module is still functional without its XS parts.  When an XS module is build
    with `--pureperl_only`, it will otherwise fail.

    It affects to [Module::Build](https://metacpan.org/pod/Module%3A%3ABuild) 0.4005+ only.

- no\_github\_issues

        no_github_issues=true

    Minilla sets bugtracker to github/GitLab's issue tracker by default. But if you
    want to use RT, you can set this variable.

- no\_index

        [no_index]
        directory=['t', 'xt', 'tools']

    Minilla sets META.json's no\_index as `directory => ['t', 'xt', 'inc', 'share', 'eg', 'examples', 'author', 'builder']`
    by default. But if you want to change them, you can set this section variable. If this section is set,
    specified variables are only used, in fact default settings are not merged.

- c\_source

        c_source = ['src']

    A directory which contains C source files that the rest of the build may depend
    on.  Any ".c" files in the directory will be compiled to object files.
    The directory will be added to the search path during the compilation and
    linking phases of any C or XS files.

- script\_files

        script_files = ['bin/foo', 'script/*']

    Minilla sets install script files as `['script/*', 'bin/*']` by default.

    (Note. This option doesn't affect anything if you are using ModuleBuildTiny or ExtUtilsMakeMaker, for now. If you are using ModuleBuildTiny, you MUST put scripts in script/ directory.)

- tap\_harness\_args(EXPERIMENTAL)

        [tap_harness_args]
        jobs=19

    This parameters pass to TAP::Harness when running tests. See the [TAP::Harness](https://metacpan.org/pod/TAP%3A%3AHarness) documentation for details.

- license

        license="artistic_2"

    You can specify your favorite license on minil.toml. The license key is same as CPAN Meta spec 2.0.
    See [CPAN::Meta::Spec](https://metacpan.org/pod/CPAN%3A%3AMeta%3A%3ASpec).

- badges

        badges = ['travis-ci.com', 'travis-ci.org', 'circleci', 'appveyor', 'coveralls', 'codecov', 'gitter', 'metacpan', 'kritika', 'github-actions/$workflow_file', 'gitlab-pipeline', 'gitlab-coverage']

    Embed badges image (e.g. Travis-CI) to README.md. It ought to be array and each elements must be service name. Now, supported services are 'travis-ci.com', 'travis-ci.org', 'circleci', 'appveyor', 'coveralls', 'codecov', 'gitter', 'metacpan', 'kritika' 'github-actions', 'gitlab-pipeline' and 'gitlab-coverage'.

    You can send additional parameters as required by your CI provider by including a
    query string along with your service name: e.g. `travis?token=[YOUR_TOKEN_GOES_HERE]&branch=dev`

- PL\_files

    Specify the PL files.

        [PL_files]
        lib/Foo/Bar.pm.PL="lib/Foo/Bar.pm"

    This option is not supported by [Minilla::ModuleMaker::ModuleBuildTiny](https://metacpan.org/pod/Minilla%3A%3AModuleMaker%3A%3AModuleBuildTiny).

    Note. MBTiny executes \*.PL files by default.

- build.build\_class

    Specify a custom Module::Build subclass.

        [build]
        build_class = "builder::MyBuilder"

- XSUtil.needs\_compiler\_c99

        [XSUtil]
        needs_compiler_c99 = 1

    You can specify `needs_compiler_c99` parameter of [Module::Build::XSUtil](https://metacpan.org/pod/Module%3A%3ABuild%3A%3AXSUtil).

- XSUtil.needs\_compiler\_cpp

        [XSUtil]
        needs_compiler_cpp = 1

    You can specify `needs_compiler_cpp` parameter of [Module::Build::XSUtil](https://metacpan.org/pod/Module%3A%3ABuild%3A%3AXSUtil).

- XSUtil.generate\_ppport\_h

        [XSUtil]
        generate_ppport_h = 1

    You can specify `generate_ppport_h` parameter of [Module::Build::XSUtil](https://metacpan.org/pod/Module%3A%3ABuild%3A%3AXSUtil).

- XSUtil.generate\_xshelper\_h

        [XSUtil]
        generate_xshelper_h = 1

    You can specify `generate_xshelper_h` parameter of [Module::Build::XSUtil](https://metacpan.org/pod/Module%3A%3ABuild%3A%3AXSUtil).

- XSUtil.cc\_warnings

        [XSUtil]
        cc_warnings = 1

    You can specify `cc_warnings` parameter of [Module::Build::XSUtil](https://metacpan.org/pod/Module%3A%3ABuild%3A%3AXSUtil).

- FileGatherer.exclude\_match

        [FileGatherer]
        exclude_match = ['^author_tools/.*']

    Nothing by default. To exclude certain files from being gathered into dist, use the
    `exclude_match` option. Files matching the patterns are not gathered.

- FileGatherer.include\_dotfiles

        [FileGatherer]
        include_dotfiles = false

    By default, files will not be included in dist if they begin with a dot. This goes
    both for files and for directories.

    In almost all cases, the default value (false) is correct.

- release.pause\_config

        [release]
        pause_config = "/path/to/some/.pause"

    By setting this value to another PAUSE configuration file (see
    ["CONFIGURATION" in cpan-upload](https://metacpan.org/pod/cpan-upload#CONFIGURATION) for the details), it is possible to use another
    PAUSE server (or anything good enough to mimick its upload process) for the
    release step.

    To do so, simply add a `upload_uri` entry in your file to the alternate PAUSE
    server, i.e :

        upload_uri http://127.0.0.1:5000/pause/authenquery

    If you instantly launch your origin upload server as DarkPAN, See [OrePAN2::Server](https://metacpan.org/pod/OrePAN2%3A%3AServer).

- release.do\_not\_upload\_to\_cpan

        [release]
        do_not_upload_to_cpan=true

    This variable disables CPAN upload feature.

- release.hooks

        [release]
        hooks = [
            "COMMAND1",
            "COMMAND2"
        ]

    Commands that are specified by this option will be executed when releasing. If result of commands is not successful, it will abort.

- release.branch

        [release]
        branch = "main"

    If this value does not match the current branch, it will abort.

- unsupported.os

        [unsupported]
        os = [
            "MSWin32",
            "darwin"
        ]

    By setting this value to add unsupported OS checks for (Build.PL|Makefile.PL).

- ReleaseTest.MinimumVersion

        [ReleaseTest]
        MinimumVersion = false

    If you set this key false, Minilla will not generate 'xt/minilla/minimum\_version.t'.

- requires\_external\_bin

        requires_external_bin=['tar']

    The `requires_external_bin` command takes the name of a system command
    or program. Build fail if the command does not exist.

- markdown\_maker

        markdown_maker = "Pod::Markdown::Github"

    Use a different module to generate `README.md` from your pod. This
    module must subclass [Pod::Markdown](https://metacpan.org/pod/Pod%3A%3AMarkdown).

- markdown\_maker\_opts

        [markdown_maker_opts]
        local_module_re = "^MyApp::"
        local_module_url_prefix = "https://example.org/perl/pod/"

    Specify arguments to pass to `markdown_maker`'s `new()` constructor.

- Metadata

        [Metadata]
        x_deprecated = 1

    Add arbitrary keys to `META.json`/`META.yml`.

- static\_install

        static_install = "auto"

    If `static_install = "auto"` (or nothing is specified at all),
    then minil tries to detect whether distributions are ready for static install or not, and set `x_static_install` in META files accordingly.
    You can also set `static_install = 0/1` explicitly; then minil will respect it.

    For static install itself, please refer to [https://github.com/Perl-Toolchain-Gang/cpan-static](https://github.com/Perl-Toolchain-Gang/cpan-static).

# FAQ

- How can I manage **contributors** section?

    Minilla aggregates contributors list from `git log --format="%aN <%aE>" | sort | uniq`.

    You can merge accounts by .mailmap file. See [https://www.kernel.org/pub/software/scm/git/docs/git-shortlog.html](https://www.kernel.org/pub/software/scm/git/docs/git-shortlog.html)

- Why don't you provide plug-in support?

    If you want a pluggable tool, it already exists: It's called [Dist::Zilla](https://metacpan.org/pod/Dist%3A%3AZilla) :P
    If you like Minilla's behavior but you really want something pluggable, you can use [Dist::Milla](https://metacpan.org/pod/Dist%3A%3AMilla), Minilla's sister project.
    [Dist::Milla](https://metacpan.org/pod/Dist%3A%3AMilla)'s behavior is almost identical to that of Minilla.

- Why does minil only support git?

    I think git is a best VC for CPAN modules, for now.

    If you want to use another version control system, you can probably use [Dist::Milla](https://metacpan.org/pod/Dist%3A%3AMilla).

- And why...

    Yes. You can use [Dist::Milla](https://metacpan.org/pod/Dist%3A%3AMilla).

- Should I add (META.json|Build.PL) to repository?

    Yes. You need to add it to make your git repo installable via cpanm.

- How do I manage ppport.h?

    Is there a reason to remove ppport.h from repo?

- How can I install script files?

    Your executables must be in `script/` directory.

- How to switch from Module::Install/Module::Build/Dist::Zilla?

    You can use experimental \`minil migrate\` sub-command.
    See [Minilla::CLI::Migrate](https://metacpan.org/pod/Minilla%3A%3ACLI%3A%3AMigrate) for more details.

- How should I manage the files you do not want to upload to CPAN?

    Please use FileGatherer.exclude\_match for ignoring files to upload tar ball.

    You can use MANIFEST.SKIP file for ignoring files. ref. [ExtUtils::Manifest](https://metacpan.org/pod/ExtUtils%3A%3AManifest).

- How do I use Module::Build::Tiny with Minilla?

    Minilla supports Module::Build::Tiny and uses it as a default installer since v1.0.0.

    If you want to migrate an existing project created before Minilla v1.0, you need to rewrite `minil.toml` file.
    You need to add the following line:

        module_maker="ModuleBuildTiny"

- How do I use Module::Build with Minilla?

    If you want to create new project with Module::Build, run the command as following.

        % minil new -p ModuleBuild My::Awesome::Module

- How do I use ExtUtils::MakeMaker with Minilla?

    Minilla v2.1.0+ supports EUMM(EXPERIMENTAL).

    You need to rewrite minil.toml file and add the following line:

        module_maker="ExtUtilsMakeMaker"

    (There is no profile, yet. Patches welcome.)

    I don't suggest to use this module... But you can use this option for maintaining
    primitive modules like Test::TCP.

- Ho do I support Perl 5.6?

    EUMM can run on Perl 5.6. Write following statement in your minil.toml file.

        module_maker="ExtUtilsMakeMaker"

# bash/zsh completion

Minilla provides bash and zsh completion files under `contrib/` directory.

# AUTHORS

Tokuhiro Matsuno < tokuhirom@gmail.com >

Tatsuhiko Miyagawa

# THANKS TO

RJBS, the author of [Dist::Zilla](https://metacpan.org/pod/Dist%3A%3AZilla). [Dist::Zilla](https://metacpan.org/pod/Dist%3A%3AZilla) points CPAN authorizing tool.

# SEE ALSO

# LICENSE

Copyright (C) Tokuhiro Matsuno

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
