package Minya::Skelton;
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

use Minya::License;
use Minya::Util qw(spew);

use Moo;

has [qw(c dist author path module version email)] => (
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
    $self->render('minya.toml');
    $self->render('t/00_compile.t');

    $self->write_file('.gitignore', get_data_section('.gitignore'));
    $self->write_file('cpanfile', get_data_section('cpanfile'));
    $self->write_file('LICENSE', Minya::License->perl_5($self->author, $self->email));

    # Generate Build.PL and META.json for installable git repo.
    $self->write_file('Build.PL', get_data_section('Build.PL'));
}

# Generate META.json
sub generate_metafile {
    my $self = shift;

    my $guard = pushd($self->dist);
    my $config = Minya::Config->load($self->c, catfile('minya.toml'));
    my $prereq_specs = Module::CPANfile->load('cpanfile')->prereq_specs;
    my $meta = Minya::CPANMeta->new(
        config => $config,
        prereq_specs => $prereq_specs,
        base_dir     => '.',
    )->generate('unstable');
    $meta->save('META.json', {version => 2.0});
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

1;
__DATA__

@@ Build.PL
use Module::Build::Tiny;
Build_PL();

@@ cpanfile
on test => sub {
    requires 'Test::More' => 0.58;
};

on configure => sub {
    requires 'Module::Build::Tiny';
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

@@ minya.toml
name = "<% module %>"

@@ Changes
Revision history for Perl extension <% dist %>

0.0.1 <% date %>

    - original version

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

