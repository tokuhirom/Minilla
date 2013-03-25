package Minilla::Profile::Default;
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

use Minilla::Project;
use Minilla::License::Perl_5;
use Minilla::Util qw(spew);

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
use 5.008005;
use Module::Build::Tiny;
Build_PL();

@@ cpanfile
requires 'perl', '5.008005';

on test => sub {
    requires 'Test::More' => 0.98;
};

on configure => sub {
    requires 'Module::Build::Tiny';
};

on 'develop' => sub {
};

