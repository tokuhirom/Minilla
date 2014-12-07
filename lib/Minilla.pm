package Minilla;
use strict;
use warnings;
use 5.008005;
use version; our $VERSION = version->declare("v2.3.0");

our $DEBUG;
our $AUTO_INSTALL;

sub debug { $DEBUG }
sub auto_install { $AUTO_INSTALL }

1;
__END__

=for stopwords MINILLA .mailmap mimick XSUtil travis XSUtil.needs_compiler_cpp XSUtil.generate_xshelper_h XSUtil.cc_warnings DarkPAN

=encoding utf8

=head1 NAME

Minilla - CPAN module authoring tool

=head1 SYNOPSIS

    minil new     - Create a new dist
    minil test    - Run test cases
    minil dist    - Make your dist tarball
    minil install - Install your dist
    minil release - Release your dist to CPAN
    minil run     - Run arbitrary commands against build dir

=head1 DESCRIPTION

Minilla is a CPAN module authoring tool. Minilla provides L<minil> command for authorizing a CPAN distribution.

    (M::I - inc) + shipit + (dzil - plugins)

B<THIS IS A DEVELOPMENT RELEASE. API MAY CHANGE WITHOUT NOTICE>.

=head1 MOTIVATION

=head1 CONVENTION

As stated above, Minilla is opinionated. Minilla has a bold assumption and convention like the followings, which are almost compatible to the sister project L<Dist::Milla>.

=over 4

=item Your module written in Pure Perl are located in I<lib/>.

=item Your executable file is in I<script/> directory, if any

=item Your module is maintained with B<Git> and C<git ls-files> matches with what you will release

=item Your module has a static list of prerequisites that can be described in L<cpanfile>

=item Your module has a Changes file

=back

=head1 GETTING STARTED

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

You already have distributions with L<Module::Install>, L<Module::Build>, L<Dist::Zilla> or L<ShipIt>? Migrating is also trivial. See "MIGRATING" in L<Minilla::Tutorial> for more details.

=head1 WHY MINILLA?

=head2 Repository managed by Minilla is git install ready.

The repository created and managed by Minilla is git install ready.
You can install the library by C<< cpanm git://... >>.

Of course, you can install Minilla from C<< cpanm git://github.com/tokuhirom/Minilla.git >>.

=head2 Minilla is built on small libraries.

Minilla is built on only few small libraries. You can install Minilla without a huge list of dependencies to heavy modules.

=head2 And, what is Minilla?

    Minilla is a Kaiju (Japanese giant monster) from the Godzilla series of films and is the first of several young Godzillas.
    http://en.wikipedia.org/wiki/Minilla

=head1 CONFIGURATION

Minilla uses B<Convention over Configuration>.

But, you can write configurations to I<minil.toml> file in L<TOML|https://github.com/mojombo/toml> format. Minilla reads the I<minil.toml> file in the root directory of your project.

=over 4

=item name

You can write 'name' instead of automatically detecting project name out of the directory name.

=item readme_from

    readme_from="lib/My/Foo.pod"

You can specify the file to generate the README.md. This is a main module path by default.

=item tag_format

    tag_format="perl/%v"

format of the tag to apply. Defaults to %v. C<%v> will replace with the distribution version.

=item abstract_from

    abstract_from="lib/My/Foo.pod"

Grab abstract information from the file contains pod.

=item authors_from

    authors_from="lib/My/Foo.pod"

Grab authors information from the file contains pod.

=item authority

    authority = "cpan:TOKUHIROM"

Set x_authority attribute to META.
See L<http://jawnsy.wordpress.com/2011/02/20/what-is-x_authority/> for more details.

=item allow_pureperl

    allow_pureperl=1

A boolean indicating the module is still functional without its XS parts.  When an XS module is build
with C<--pureperl_only>, it will otherwise fail.

It affects to L<Module::Build> 0.4005+ only.

=item no_github_issues

    no_github_issues=true

Minilla sets bugtracker as github issues by default. But if you want to use RT, you can set this variable.

=item no_index

    [no_index]
    directory=['t', 'xt', 'tools']

Minilla sets META.json's no_index as C<< directory => ['t', 'xt', 'inc', 'share', 'eg', 'examples', 'author', 'builder'] >>
by default. But if you want to change them, you can set this section variable. If this section is set,
specified variables are only used, in fact default settings are not merged.

=item c_source

    c_source = ['src']

A directory which contains C source files that the rest of the build may depend
on.  Any ".c" files in the directory will be compiled to object files.
The directory will be added to the search path during the compilation and
linking phases of any C or XS files.

=item script_files

    script_files = ['bin/foo', 'script/*']

Minilla sets install script files as C<< ['script/*', 'bin/*'] >> by default.

(Note. This option doesn't affect anything if you are using ModuleBuildTiny or ExtUtilsMakeMaker, for now. If you are using ModuleBuildTiny, you MUST put scripts in bin/ directory.)

=item tap_harness_args(EXPERIMENTAL)

    [tap_harness_args]
    jobs=19

This parameters pass to TAP::Harness when running tests. See the L<TAP::Harness> documentation for details.

=item license

    license="artistic_2"

You can specify your favorite license on minil.toml. The license key is same as CPAN Meta spec 2.0.
See L<CPAN::Meta::Spec>.

=item badges

    badges = ['travis', 'coveralls', 'gitter']

Embed badges image (e.g. Travis-CI) to README.md. It ought to be array and each elements must be service name. Now, supported services are only 'travis', 'coveralls' and 'gitter'.

=item PL_files

Specify the PL files.

    [PL_files]
    lib/Foo/Bar.pm.PL="lib/Foo/Bar.pm"

This option is not supported by L<Minilla::ModuleMaker::ModuleBuildTiny>.

Note. MBTiny executes *.PL files by default.

=item build.build_class

Specify a custom Module::Build subclass.

    [build]
    build_class = "builder::MyBuilder"

=item XSUtil.needs_compiler_c99

    [XSUtil]
    needs_compiler_c99 = 1

You can specify C<needs_compiler_c99> parameter of L<Module::Build::XSUtil>.

=item XSUtil.needs_compiler_cpp

    [XSUtil]
    needs_compiler_cpp = 1

You can specify C<needs_compiler_cpp> parameter of L<Module::Build::XSUtil>.

=item XSUtil.generate_ppport_h

    [XSUtil]
    generate_ppport_h = 1

You can specify C<generate_ppport_h> parameter of L<Module::Build::XSUtil>.

=item XSUtil.generate_xshelper_h

    [XSUtil]
    generate_xshelper_h = 1

You can specify C<generate_xshelper_h> parameter of L<Module::Build::XSUtil>.

=item XSUtil.cc_warnings

    [XSUtil]
    cc_warnings = 1

You can specify C<cc_warnings> parameter of L<Module::Build::XSUtil>.

=item FileGatherer.exclude_match

    [FileGatherer]
    exclude_match = ['^author_tools/.*']

Nothing by default. To exclude certain files from being gathered into dist, use the
C<exclude_match> option. Files matching the patterns are not gathered.

=item FileGatherer.include_dotfiles

    [FileGatherer]
    include_dotfiles = false

By default, files will not be included in dist if they begin with a dot. This goes
both for files and for directories.

In almost all cases, the default value (false) is correct.

=item release.pause_config

    [release]
    pause_config = "/path/to/some/.pause"

By setting this value to another PAUSE configuration file (see
L<cpan_upload/CONFIGURATION> for the details), it is possible to use another
PAUSE server (or anything good enough to mimick its upload process) for the
release step.

To do so, simply add a C<upload_uri> entry in your file to the alternate PAUSE
server, i.e :

    upload_uri http://127.0.0.1:5000/pause/authenquery

If you instantly launch your origin upload server as DarkPAN, See L<OrePAN2::Server>.

=item release.do_not_upload_to_cpan

    [release]
    do_not_upload_to_cpan=true

This variable disables CPAN upload feature.

=item release.hooks

    [release]
    hooks = [
        "COMMAND1",
        "COMMAND2"
    ]

Commands that are specified by this option will be executed when releasing. If result of commands is not successful, it will abort.

=item ReleaseTest.MinimumVersion

    [ReleaseTest]
    MinimumVersion = false

If you set this key false, Minilla will not generate 'xt/minilla/minimum_version.t'.

=item requires_external_bin

    requires_external_bin=['tar']

The C<requires_external_bin> command takes the name of a system command
or program. Build fail if the command does not exist.

=back

=head1 FAQ

=over 4

=item How can I manage B<contributors> section?

Minilla aggregates contributors list from C<< git log --format="%aN <%aE>" | sort | uniq >>.

You can merge accounts by .mailmap file. See L<https://www.kernel.org/pub/software/scm/git/docs/git-shortlog.html>

=item Why don't you provide plug-in support?

If you want a pluggable tool, it already exists: It's called L<Dist::Zilla> :P
If you like Minilla's behavior but you really want something pluggable, you can use L<Dist::Milla>, Minilla's sister project.
L<Dist::Milla>'s behavior is almost identical to that of Minilla.

=item Why does minil only support git?

I think git is a best VC for CPAN modules, for now.

If you want to use another version control system, you can probably use L<Dist::Milla>.

=item And why...

Yes. You can use L<Dist::Milla>.

=item Should I add (META.json|Build.PL) to repository?

Yes. You need to add it to make your git repo installable via cpanm.

=item How do I manage ppport.h?

Is there a reason to remove ppport.h from repo?

=item How can I install script files?

Your executables must be in F<script/>. It's L<Module::Build::Tiny>'s rule.

=item How to switch from Module::Install/Module::Build/Dist::Zilla?

You can use experimental `minil migrate` sub-command.
See L<Minilla::CLI::Migrate> for more details.

=item How should I manage the files you do not want to upload to CPAN?

Please use FileGatherer.exclude_match for ignoring files to upload tar ball.

You can use MANIFEST.SKIP file for ignoring files. ref. L<ExtUtils::Manifest>.

=item How do I use Module::Build::Tiny with Minilla?

Minilla v0.15.0+ supports v0.15.0(EXPERIMENTAL).

If you want to create new project with Module::Build::Tiny, run the command as following.

    % minil new -p ModuleBuildTiny My::Awesome::Module

If you want to migrate existing project, you need to rewrite minil.toml file.
You need to add following line:

    module_maker="ModuleBuildTiny"

=item How do I use ExtUtils::MakeMaker with Minilla?

Minilla v2.1.0+ supports EUMM(EXPERIMENTAL).

You need to rewrite minil.toml file.
You need to add following line:

    module_maker="ExtUtilsMakeMaker"

(There is no profile, yet. Patches welcome.)

I don't suggest to use this module... But you can use this option for maintaining
primitive modules like Test::TCP.

=back

=head1 AUTHORS

Tokuhiro Matsuno E<lt> tokuhirom@gmail.com E<gt>

Tatsuhiko Miyagawa

=head1 THANKS TO

RJBS, the author of L<Dist::Zilla>. L<Dist::Zilla> points CPAN authorizing tool.

=head1 SEE ALSO

=head1 LICENSE

Copyright (C) Tokuhiro Matsuno

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
