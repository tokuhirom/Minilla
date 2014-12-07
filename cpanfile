requires 'perl'   => '5.008005';

# Core module at recent Perl5.
requires 'parent' => '0';
requires 'Archive::Tar', '1.60';
requires 'Time::Piece' => 1.16; # older Time::Piece was broken
requires 'version';
requires 'CPAN::Meta', '2.132830'; # merged_requirements is 2.132830+
requires 'ExtUtils::Manifest', 1.54; # make maniskip a public routine, and allow an argument to override $mfile
suggests 'Devel::PPPort'; # XS
requires 'TAP::Harness::Env'; # From 5.19.5

# Module for compatibility
requires 'MRO::Compat' if $] < 5.009_005;

# The TOML parser
requires 'TOML', 0.95;

# Templating
requires 'Text::MicroTemplate', '0.20';

# CPAN related
requires 'App::cpanminus', '1.6902';
requires 'Module::CPANfile', '0.9025';
requires 'Module::Metadata' => '1.000012';
requires 'Pod::Markdown', '1.322';
requires 'Config::Identity';

# File operation
requires 'File::pushd';
requires 'File::Copy::Recursive';
requires 'File::Which';

# OOPS
requires 'Moo' => 1.001000;

# Utilities
requires 'Data::Section::Simple' => 0.04;
requires 'Term::ANSIColor';

# Modules required by minil new/minil dist/minil release are optional.
# It's good for contributors
recommends 'Version::Next';
recommends 'Pod::Escapes';
recommends 'CPAN::Uploader';

# Core deps
requires 'Try::Tiny';
requires 'Getopt::Long', 2.36;

# Module required for license otherwise Perl_5 license.
recommends 'Software::License', '0.103010';

# release testing
recommends 'Test::Pod';
recommends 'Test::Spellunker', 'v0.2.7';
recommends 'Test::MinimumVersion' => '0.101080';
recommends 'Test::CPAN::Meta';
recommends 'Test::PAUSE::Permissions';

on 'test' => sub {
    requires 'Test::More' => '0.98';
    requires 'Test::Requires' => 0;
    requires 'Test::Output';
    requires 'File::Temp';
    recommends 'Devel::CheckLib';
    suggests 'Dist::Zilla';
    requires 'CPAN::Meta::Validator';
    requires 'JSON';
    requires 'Module::Build::Tiny', 0.035; # https://github.com/tokuhirom/Minilla/issues/151
};

on 'configure' => sub {
    requires 'Module::Build';
};

on 'develop' => sub {
    # Dependencies for developers
};
