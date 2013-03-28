use strict;
use Module::Build;
use Module::CPANfile;
use File::Basename;
use File::Spec;
use CPAN::Meta;

use 5.008005;

my $builder = Module::Build->new(
    license              => 'perl',
    dynamic_config       => 0,

    requires             => {
        perl => '5.008005',
    },
    configure_requires => {
        'Module::Build' => 0.40,
        'Module::CPANfile' => 0.9008, # merge_meta
    },

    no_index    => { 'directory' => [ 'inc' ] },
    name        => 'Acme-Foo',
    module_name => 'Acme::Foo',

    script_files => [glob('script/*')],

    test_files           => ((-d '.git' || $ENV{RELEASE_TESTING}) && -d 'xt') ? 't/ xt/' : 't/',
    recursive_test_files => 1,

    create_readme  => 0,
    create_license => 0,
);
$builder->create_build_script();

my $cpanfile = Module::CPANfile->load();
for my $metafile (grep -e, qw(MYMETA.yml MYMETA.json)) {
    print "Merging cpanfile prereqs to $metafile\n";
    $cpanfile->merge_meta($metafile)
}

