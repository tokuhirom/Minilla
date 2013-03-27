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

has [qw(dist author path module version email suffix)] => (
    is       => 'ro',
    required => 1,
);

no Moo;

sub date {
    gmtime->strftime('%Y-%m-%dT%H:%M:%SZ');
}

sub end { '__END__' }

sub module_pm_src { '' }

sub render {
    my ($self, $tmplname, $dst, $params) = @_;
    my $path = $dst || $tmplname;

    infof("Writing %s\n", $path);
    mkpath(dirname($path));

    for my $pkg (@{mro::get_linear_isa(ref $self || $self)}) {
        my $content = Data::Section::Simple->new($pkg)->get_data_section($tmplname);
        next unless defined $content;
        $content =~ s!<%\s*\$([a-z_]+)\s*%>!
            if (ref $self) {
                $self->$1()
            } else {
                $params->{$1}
            }
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
use strict;
use warnings;
use 5.008005;
our $VERSION = "<% $version %>";

<% $module_pm_src %>

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

@@ .travis.yml
language: perl
perl:
  - 5.16
  - 5.14

@@ Changes
Revision history for Perl extension <% $dist %>

{{$NEXT}}

    - original version

@@ .gitignore
/.build/
/_build/
/carton.lock
/.carton/
/local/
/nytprof.out
/nytprof/
/Build

