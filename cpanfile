requires 'perl' => '5.0120005';
requires 'parent'                        => '0';
requires 'Module::Build' => 0.40;
requires 'Archive::Tar';
requires 'App::cpanminus';
requires 'Module::CPANfile';
requires 'File::pushd';
requires 'Path::Tiny';
requires 'Moo' => 1.001000;

# Modules required by minya new/minya dist/minya release are optional.
# It's good for contributors
recommends 'Perl::Version';
recommends 'Pod::Escapes';
recommends 'CPAN::Uploader';
recommends 'CPAN::Meta::Check';

requires 'TOML' => 0.91;

on 'configure' => sub {
    requires 'Module::Build' => '0.40';
};

on 'test' => sub {
    requires 'Test::More' => '0.98';
    requires 'Test::Requires' => 0;
};

on 'develop' => sub {
    # Dependencies for developers
    # recommends 'Test::Kwalitee';
};
