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

use Minya::License;
use Minya::Util;

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

    # Generate Build.PL and META.json for installable git repo.
    $self->write_file('Build.PL', get_data_section('Build.PL'));

    my $data = {
        "meta-spec" => {
            "version" => "2",
            "url"     => "http://search.cpan.org/perldoc?CPAN::Meta::Spec"
        },
        abstract => "blah blah blah",
        author => $self->author,
        dynamic_config => 0,
        license => 'perl_5',
        version => $self->version,
        name => $self->dist,
        prereqs => Module::CPANfile->load(catfile($self->dist, 'cpanfile'))->prereq_specs,
        generated_by => "Minya/$Minya::VERSION",
        release_status => 'unstable',
    };
    CPAN::Meta->new($data)->save(catfile($self->dist, 'META.json'), {version => '2.0'});

    $self->write_file('LICENSE', Minya::License->perl_5($self->author, $self->email));
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
requires 'perl' => '5.008005';

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

