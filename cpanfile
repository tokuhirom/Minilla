requires 'perl'   => '5.0120005';
requires 'parent' => '0';
requires 'Archive::Tar';
requires 'App::cpanminus';
requires 'Module::CPANfile';
requires 'File::pushd';
requires 'Path::Tiny';
requires 'Moo' => 1.001000;
requires 'Data::Section::Simple';
requires 'Module::Metadata';

# Modules required by minil new/minil dist/minil release are optional.
# It's good for contributors
recommends 'Perl::Version';
recommends 'Pod::Escapes';
recommends 'CPAN::Uploader';
recommends 'CPAN::Meta::Check';

# Module required for license otherwise Perl_5 license.
recommends 'Software::License';

# release testing
recommends 'Test::Pod';
recommends 'Test::Spelling';
recommends 'Pod::Wordlist::hanekomu';
recommends 'Test::MinimumVersion' => '0.101080';
recommends 'Test::CPAN::Meta';
recommends 'Pod::Wordlist::hanekomu';

requires 'TOML' => 0.91;

on 'configure' => sub {
    requires 'Module::Build::Tiny';
};

on 'test' => sub {
    requires 'Test::More' => '0.98';
    requires 'Test::Requires' => 0;
    requires 'Test::AllModules';
};

on 'develop' => sub {
    # Dependencies for developers
    # recommends 'Test::Kwalitee';
};
