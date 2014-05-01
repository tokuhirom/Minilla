package Minilla::Profile::Base;
use strict;
use warnings;
use utf8;
use File::Spec::Functions qw(catfile);
use File::Path qw(mkpath);
use File::Basename qw(dirname);
use Data::Section::Simple;
use Time::Piece;

use Minilla::Util qw(spew_raw);
use Minilla::Logger;

BEGIN { eval "use MRO::Compat;1" or die $@ if $] < 5.009_005 }

use Moo;

has [qw(dist path module)] => (
    is       => 'ro',
    required => 1,
);

has 'version' => (
    is       => 'ro',
    default  => sub { '0.01' },
);

has suffix => (
    is => 'lazy',
    required => 1,
);

has [qw(email author)] => (
    is => 'lazy',
    required => 1,
);

no Moo;

sub _build_author {
    my $self = shift;

    my $name ||= `git config user.name`;
    $name =~ s/\n$//;

    unless ($name) {
        errorf("You need to set user.name in git config.\nRun: git config user.name 'Your name'\n");
    }

    $name;
}

sub _build_email {
    my $self = shift;

    my $email ||= `git config user.email`;
    $email =~ s/\n$//;

    unless ($email) {
        errorf("You need to set user.email in git config.\nRun: git config user.email 'name\@example.com'\n");
    }

    $email;
}

sub _build_suffix {
    my $self = shift;
    my $suffix = $self->path;
    $suffix =~ s!^.+/!!;
    $suffix =~ s!\.pm!!;
    $suffix;
}

sub new_from_project {
    my ($class, $project) = @_;

    my $path = $project->main_module_path;
    $path =~ s!^lib/!!;
    my $self = $class->new(
        dist    => $project->dist_name,
        author  => $project->authors ? $project->authors->[0] : 'Unknown Author',
        version => $project->version,
        path    => $path,
        module  => $project->name,
    );
    return $self;
}

sub date {
    gmtime->strftime('%Y-%m-%dT%H:%M:%SZ');
}

sub end { '__END__' }

sub module_pm_src { '' }

sub render {
    my ($self, $tmplname, $dst) = @_;
    my $path = $dst || $tmplname;

    infof("Writing %s\n", $path);
    mkpath(dirname($path));

    for my $pkg (@{mro::get_linear_isa(ref $self || $self)}) {
        my $content = Data::Section::Simple->new($pkg)->get_data_section($tmplname);
        next unless defined $content;
        $content =~ s!<%\s*\$([a-z_]+)\s*%>!
            $self->$1()
        !ge;
        spew_raw($path, $content);
        return;
    }
    errorf("Cannot find template for %s\n", $tmplname);
}

sub write_file {
    my ($self, $path, $content) = @_;

    infof("Writing %s\n", $path);
    mkpath(dirname($path));
    spew_raw($path, $content);
}


1;
__DATA__

@@ t/00_compile.t
use strict;
use Test::More;

use_ok $_ for qw(
    <% $module %>
);

done_testing;

@@ Module.pm
package <% $module %>;
use 5.008005;
use strict;
use warnings;

our $VERSION = "<% $version %>";

<% $module_pm_src %>

1;
<% $end %>

=encoding utf-8

=head1 NAME

<% $module %> - It's new $module

=head1 SYNOPSIS

    use <% $module %>;

=head1 DESCRIPTION

<% $module %> is ...

=head1 LICENSE

Copyright (C) <% $author %>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

<% $author %> E<lt><% $email %>E<gt>

=cut

@@ .travis.yml
language: perl
perl:
  - 5.12
  - 5.14
  - 5.16
  - 5.18

@@ Changes
Revision history for Perl extension <% $dist %>

{{$NEXT}}

    - original version

@@ .gitignore
/.build/
/_build/
/Build
/Build.bat
/blib

/carton.lock
/.carton/
/local/

nytprof.out
nytprof/

cover_db/

*.bak
*.old
*~
*.swp
*.o
*.obj

!LICENSE

/_build_params

MYMETA.*

/<% $dist %>-*
