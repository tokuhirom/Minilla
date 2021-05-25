package Minilla::Profile::ExtUtilsMakeMaker;
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

sub generate {
    my $self = shift;

    $self->render('Module.pm', catfile('lib', $self->path));

    $self->render('Changes');
    $self->render('t/00_compile.t');
    $self->render('.travis.yml');

    $self->render('.gitignore');
    $self->write_file('LICENSE', $self->license->fulltext);

    $self->render('cpanfile');
}

1;
__DATA__

@@ cpanfile
requires 'perl', '5.008001';

on 'test' => sub {
    requires 'Test::More', '0.98';
};
