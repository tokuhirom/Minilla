package Minilla::Skeleton;
use strict;
use warnings;
use utf8;
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

use Moo;

has [qw(mb c dist author path module version email)] => (
    is       => 'ro',
    required => 1,
);

no Moo;

sub date {
    gmtime->strftime('%Y-%m-%dT%H:%M:%SZ');
}

sub end {
    '__END__'
}

sub generate {
    my $self = shift;

    $self->render('Module.pm', 'lib', $self->path);

    $self->render('Changes');
    $self->render('t/00_compile.t');
    $self->render('.travis.yml');

    $self->write_file('.gitignore', get_data_section('.gitignore'));
    $self->write_file('LICENSE', Minilla::License::Perl_5->new(
        holder => sprintf('%s <%s>', $self->author, $self->email)
    )->fulltext);

    # Generate Build.PL and META.json for installable git repo.
    if ($self->mb) {
        $self->write_file('cpanfile', get_data_section('cpanfile-MB'));
        $self->render('Build-MB.PL', 'Build.PL');
    } else {
        $self->write_file('cpanfile', get_data_section('cpanfile-Tiny'));
        $self->render('Build-Tiny.PL', 'Build.PL');
    }
}

# Generate META.json
sub generate_metafile {
    my $self = shift;

    my $guard = pushd($self->dist);
    Minilla::Project->new(
        c => $self->c
    )->regenerate_meta_json();
}

sub render {
    my $self = shift;
    my $tmpl = shift;
    my $path = catfile($self->dist, @_ ? @_ : $tmpl);
    $self->c->infof("Writing %s\n", $path);
    mkpath(dirname($path));
    my $content = get_data_section($tmpl);
    $content =~ s!<%\s*([a-z_]+)\s*%>!$self->$1!ge;
    spew($path, $content);
}

sub write_file {
    my $self = shift;
    my $content = pop;

    my $path = catfile($self->dist, @_);
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

@@ Build-Tiny.PL
use Module::Build::Tiny;
Build_PL();

@@ cpanfile-Tiny
requires 'parent';

on test => sub {
    requires 'Test::More' => 0.58;
};

on configure => sub {
    requires 'Module::Build::Tiny';
};

on 'develop' => sub {
};

@@ Build-MB.PL
use strict;
use Module::Build;
use Module::CPANfile;
use File::Basename;
use File::Spec;

use 5.008005;

my $cpanfile = Module::CPANfile->load('cpanfile');
my $prereqs = $cpanfile->prereq_specs;

my $builder = Module::Build->new(
    license              => 'perl',
    dynamic_config       => 0,

    requires             => {
        perl => '5.008005',
        %{ $prereqs->{runtime}->{requires} || {} },
    },
    configure_requires => {
        %{ $prereqs->{runtime}->{requires}  || {}},
    },
    build_requires => {
        %{ $prereqs->{build}->{requires}  || {}},
        %{ $prereqs->{test}->{requires}   || {}},
    },

    no_index    => { 'directory' => [ 'inc' ] },
    name        => '<% dist %>',
    module_name => '<% module %>',

    script_files => [glob('script/*')],

    test_files           => ((-d '.git' || $ENV{RELEASE_TESTING}) && -d 'xt') ? 't/ xt/' : 't/',
    recursive_test_files => 1,

    create_readme  => 1,
    create_license => 0,
);
$builder->create_build_script();

@@ cpanfile-MB
requires 'parent';

on test => sub {
    requires 'Test::More' => 0.98;
};

on configure => sub {
    requires 'Module::Build' => 0.40;
    requires 'Module::CPANfile';
};

on 'develop' => sub {
    # xt/minimum_bersion.t
    requires 'Test::MinimumVersion' => '0.101080';

    # xt/cpan_meta.t
    requires 'Test::CPAN::Meta';

    # xt/pod.t
    requires 'Test::Pod' => 1.41;

    # xt/spelling.t
    requires 'Test::Spelling';
    requires 'Pod::Wordlist::hanekomu';
};

@@ .gitignore
/.build/
/_build/
/carton.lock
/.carton/
/local/
/nytprof.out
/nytprof/

@@ t/00_compile.t
use strict;
use Test::More;

use_ok $_ for qw(
    <% module %>
);

done_testing;

@@ Changes
Revision history for Perl extension <% dist %>

0.0.1 <% date %>

    - original version

@@ .travis.yml
language: perl
perl:
  - 5.16
  - 5.14

@@ Module.pm
package <% module %>;
use strict;
use warnings;
use 5.008005;
our $VERSION = '<% version %>';

1;
<% end %>

=head1 NAME

<% module %> - It's new $module

=head1 SYNOPSIS
    
    use <% module %>;

=head1 DESCRIPTION

<% module %> is ...

=head1 LICENSE

Copyright (C) <% author %>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

<% author %> E<lt><% email %>E<gt>

