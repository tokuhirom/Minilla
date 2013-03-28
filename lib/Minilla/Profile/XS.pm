package Minilla::Profile::XS;
use strict;
use warnings;
use utf8;
use parent qw(Minilla::Profile::ModuleBuild);

use File::Spec::Functions qw(catfile);
use File::Basename qw(dirname);
use Data::Section::Simple qw(get_data_section);

use Minilla::Gitignore;
use Minilla::Util qw(require_optional);

sub module_pm_src {
    join("\n",
        'use XSLoader;',
        'XSLoader::load(__PACKAGE__, $VERSION);'
    );
}

sub generate {
    my $self = shift;

    require_optional( 'Devel/PPPort.pm', 'PPPort is required for XS support' );

    $self->render('Module.pm', catfile('lib', $self->path));
    $self->render('Module.xs', catfile('lib', dirname($self->path), $self->suffix . '.xs'));

    Devel::PPPort::WriteFile(catfile(dirname(catfile('lib', $self->path)), 'ppport.h'));

    $self->render('Changes');
    $self->render('t/00_compile.t');
    $self->render('t/01_simple.t');
    $self->render('.travis.yml');

    $self->render('.gitignore');
    my $gi = Minilla::Gitignore->load('.gitignore');
    $gi->add(catfile('lib', dirname($self->path), $self->suffix . '.c'));

    $self->write_file('LICENSE', Minilla::License::Perl_5->new(
        holder => sprintf('%s <%s>', $self->author, $self->email)
    )->fulltext);

    # Generate Build.PL and META.json for installable git repo.
    $self->render('cpanfile');
    $self->render('Build.PL');
}

1;
__DATA__

@@ t/01_simple.t
use strict;
use Test::More;

use <% $module %>;

is(<% $module %>::hello(), 'Hello, world!');

done_testing;

@@ Module.xs
#ifdef __cplusplus
extern "C" {
#endif

#define PERL_NO_GET_CONTEXT /* we want efficiency */
#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

#ifdef __cplusplus
} /* extern "C" */
#endif

#define NEED_newSVpvn_flags
#include "ppport.h"

MODULE = <% $module %>    PACKAGE = <% $module %>

PROTOTYPES: DISABLE

void
hello()
CODE:
{
    ST(0) = newSVpvs_flags("Hello, world!", SVs_TEMP);
}
