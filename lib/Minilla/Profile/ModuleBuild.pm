package Minilla::Profile::ModuleBuild;
use strict;
use warnings;
use utf8;

use parent qw(Minilla::Profile::Base);

use File::Spec::Functions qw(catfile);
use File::Path qw(mkpath);
use File::Basename qw(dirname);
use CPAN::Meta;
use Data::Section::Simple qw(get_data_section);
use File::pushd;

use Minilla::License::Perl_5;

sub generate {
    my $self = shift;

    $self->render('Module.pm', catfile('lib', $self->path));

    $self->render('Changes');
    $self->render('t/00_compile.t');
    $self->render('.travis.yml');

    $self->render('.gitignore');
    $self->write_file('LICENSE', Minilla::License::Perl_5->new(
        holder => sprintf('%s <%s>', $self->author, $self->email)
    )->fulltext);

    # Generate Build.PL and META.json for installable git repo.
    $self->render('cpanfile');
    $self->render('Build.PL');
}

1;
__DATA__

@@ Build.PL
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
        'Module::CPANfile' => 0,
    },

    no_index    => { 'directory' => [ 'inc' ] },
    name        => '<% $dist %>',
    module_name => '<% $module %>',

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

@@ cpanfile
on test => sub {
    requires 'Test::More' => 0.98;
};

on configure => sub {
    requires 'Module::Build' => 0.40;
    requires 'Module::CPANfile';
};

on 'develop' => sub {
};

