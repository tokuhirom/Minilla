use strict;
use Module::Build;
use 5.0120005;

my $builder = Module::Build->new(
    dynamic_config => 0,
    no_index           => { 'directory' => ['inc'] },
    name               => 'Minya',
    dist_name          => 'Minya',
    dist_version       => '0.0.1',
    license            => 'perl',
    script_files       => [ 'bin/minya' ],
    configure_requires => {
        'Module::CPANfile'                     => 0,
        'Module::Build::Pluggable::GithubMeta' => 0,
        'Module::Build::Pluggable'             => 0,
        'Module::Build::Pluggable::CPANfile'   => 0,
        'Module::Build'                        => '0.40'
    },
    requires => {
        'parent'                    => 0,
        'CPAN::Meta::Check'         => 0,
        'File::HomeDir'             => 0,
        'YAML::Tiny'                => 0,
        'CPAN::Uploader'            => 0,
        'Class::Accessor::Lite'     => '0.05',
        'Module::Runtime'           => 0,
        'JSON::PP'                  => 0,
        'perl'                      => '5.0120005',
        'Module::Install::CPANfile' => 0,
        'Path::Iterator::Rule'      => 0,
        'Software::License'         => 0,
        'Module::Build'             => '0.4',
        'Archive::Tar'              => 0,
        'Text::MicroTemplate'       => 0
    },
    build_requires => {},
    test_files     => 't/',

    recursive_test_files => 1,

    create_readme => 1,
);
$builder->create_build_script();
