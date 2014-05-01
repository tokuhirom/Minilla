package Minilla::Profile::ModuleBuildTiny;
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

    $self->render('cpanfile');
}

1;
__DATA__

@@ cpanfile
requires 'perl', '5.008001';

on 'test' => sub {
    requires 'Test::More', '0.98';
};

