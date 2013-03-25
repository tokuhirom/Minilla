package Minilla::Profile::Default;
use strict;
use warnings;
use utf8;
use parent qw(Minilla::Profile::Base);

use File::Spec::Functions qw(catfile);
use File::Path qw(mkpath);
use File::Basename qw(dirname);
use Time::Piece;
use CPAN::Meta;
use Data::Section::Simple qw(get_data_section);
use File::pushd;

use Minilla::Project;
use Minilla::License::Perl_5;
use Minilla::Util qw(spew);

BEGIN { eval "use MRO::Compat;1" or die $@ if $] < 5.009_005 }

sub date {
    gmtime->strftime('%Y-%m-%dT%H:%M:%SZ');
}

sub end {
    '__END__'
}

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

sub write_file {
    my ($self, $path, $content) = @_;

    $self->c->infof("Writing %s\n", $path);
    mkpath(dirname($path));
    spew($path, $content);
}

sub render_build_mb_pl {
    my ($self, $args) = @_;

    my $content = get_data_section('Build-MB.PL');
    $content =~ s!<%\s*([a-z_]+)\s*%>!$args->{$1}!ge;
    return $content;
}

1;
__DATA__

@@ Build.PL
use 5.008001;
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

@@ .gitignore
/.build/
/_build/
/carton.lock
/.carton/
/local/
/nytprof.out
/nytprof/

@@ Changes
Revision history for Perl extension <% $dist %>

<% $version %> <% $date %>

    - original version

@@ .travis.yml
language: perl
perl:
  - 5.16
  - 5.14

@@ Module.pm
package <% $module %>;
use strict;
use warnings;
use 5.008005;
our $VERSION = "<% $version %>";

1;
<% $end %>

=head1 NAME

<% $module %> - It's new $module

=head1 SYNOPSIS

    use <% $module %>;

=head1 DESCRIPTION

<% $module %> is ...

=head1 LICENSE

Copyright (C) <% $author %>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

<% $author %> E<lt><% $email %>E<gt>

