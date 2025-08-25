package Minilla::Profile::Base;
use strict;
use warnings;
use utf8;
use File::Spec::Functions qw(catfile);
use File::Path qw(mkpath);
use File::Basename qw(dirname);
use Data::Section::Simple;
use Time::Piece;

use Minilla::Util qw(spew_raw guess_license_class_by_name);
use Minilla::Logger;
use Minilla::License::Perl_5;

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

has [qw(email author license)] => (
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

sub _build_license {
    my $self = shift;
    Minilla::License::Perl_5->new({
        holder => $self->author,
    });
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

sub license_notice {
    my $self = shift;
    $self->license->notice;
}

1;
__DATA__

@@ t/00_compile.t
use strict;
use Test::More 0.98;

use_ok $_ for qw(
    <% $module %>
);

done_testing;

@@ Module.pm
package <% $module %>;
use 5.008001;
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

<% $license_notice %>

=head1 AUTHOR

<% $author %> E<lt><% $email %>E<gt>

=cut

@@ github_actions_test.yml
name: test
on: [push, pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        perl:
          [
            "5.40",
            "5.38",
            "5.36",
            "5.34",
            "5.32",
            "5.30",
            "5.28",
            "5.26",
            "5.24",
            "5.22",
            "5.20",
            "5.18",
            "5.16",
            "5.14",
            "5.12",
            "5.10"
          ]
    name: Perl ${{ matrix.perl }}
    steps:
      - uses: actions/checkout@v3
      - name: Setup perl
        uses: shogo82148/actions-setup-perl@v1
        with:
          perl-version: ${{ matrix.perl }}
      - name: Install dependencies
        run: cpanm -nq --installdeps --with-develop --with-recommends .
      - name: Run test
        run: prove -lr t

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
/Makefile
/pm_to_blib

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
