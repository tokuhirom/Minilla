use strict;
use Module::Build;

my $builder = Module::Build->new(
    license              => 'perl',
    dynamic_config       => 0,

    requires             => {
        perl => '5.008005',
    },

    no_index    => { 'directory' => [ 'inc' ] },
    name        => 'Minya',
    module_name => 'Minya',

    script_files => ['bin/minya'],

    test_files => (-d '.git' || $ENV{RELEASE_TESTING}) ? 't/ xt/' : 't/',
    recursive_test_files => 1,
   
    create_readme  => 1,
    create_license => 1,
);
$build->create_build_script();
