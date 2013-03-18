requires 'parent'                        => '0';
requires 'Module::Build' => 0.40;
requires 'Software::License';
requires 'ExtUtils::Manifest';
requires 'JSON::PP';
requires 'Text::MicroTemplate';
requires 'Class::Accessor::Lite' => 0.05;
requires 'CPAN::Meta::Check';

on 'configure' => sub {
    requires 'Module::Build' => '0.40';
    requires 'Module::Build::Pluggable';
    requires 'Module::Build::Pluggable::CPANfile';
    requires 'Module::Build::Pluggable::GithubMeta';
    requires 'Module::CPANfile';
};

on 'test' => sub {
    requires 'Test::More' => '0.98';
    requires 'Test::Requires' => 0;
};

on 'devel' => sub {
    # Dependencies for developers
};
