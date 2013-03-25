package Minilla::Profile::Base;
use strict;
use warnings;
use utf8;
use File::Spec::Functions qw(catfile);
use File::Path qw(mkpath);
use File::Basename qw(dirname);
use Data::Section::Simple qw(get_data_section);
use Minilla::Util qw(spew);

use Moo;

has [qw(c dist author path module version email)] => (
    is       => 'ro',
    required => 1,
);

no Moo;

sub render {
    my ($self, $tmplname, $dst) = @_;
    my $path = catfile($dst || $tmplname);
    $self->c->infof("Writing %s\n", $path);
    mkpath(dirname($path));

    for my $pkg (@{mro::get_linear_isa(ref $self || $self)}) {
        my $content = Data::Section::Simple->new($pkg)->get_data_section($tmplname);
        next unless defined $content;
        $content =~ s!<%\s*\$([a-z_]+)\s*%>!$self->$1!ge;
        spew($path, $content);
        return;
    }
    $self->c->error("Cannot find template for $tmplname\n");
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

