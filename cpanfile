requires 'perl'   => '5.008005';

# Core module at recent Perl5.
requires 'parent' => '0';
requires 'Archive::Tar', '1.60';
requires 'Time::Piece' => 1.16; # older Time::Piece was broken
requires 'version';
requires 'CPAN::Meta';
suggests 'Devel::PPPort'; # XS

# Module for compatibility
requires 'MRO::Compat' if $] < 5.009_005;

# The TOML parser
requires 'TOML', 0.92;

# CPAN related
requires 'App::cpanminus', '1.6902';
requires 'Module::CPANfile', '0.9025';
requires 'Module::Metadata' => '1.0.11';
requires 'Pod::Markdown';
requires 'Pod::Simple';

# File operation
requires 'File::pushd';
requires 'Path::Tiny';
requires 'File::Copy::Recursive';

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
requires 'Getopt::Long';

# Module required for license otherwise Perl_5 license.
recommends 'Software::License';

# release testing
recommends 'Test::Pod';
recommends 'Test::Spellunker', 'v0.2.2';
recommends 'Test::MinimumVersion' => '0.101080';
recommends 'Test::CPAN::Meta';

on 'test' => sub {
    requires 'Test::More' => '0.98';
    requires 'Test::Requires' => 0;
    requires 'File::Which';
    requires 'File::Temp';
    recommends 'Devel::CheckLib';
    suggests 'Dist::Zilla';
};

on 'configure' => sub {
    requires 'Module::Build';
};

on 'develop' => sub {
    # Dependencies for developers
};
