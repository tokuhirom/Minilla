use strict;
use warnings;
use utf8;
use Test::More;
use Test::Requires 'Perl::Version';
use t::Util;
use File::Spec;
use File::Path;
use File::pushd;

my $lib = File::Spec->rel2abs('lib');
my $bin = File::Spec->rel2abs('script/minil');

rmtree('Acme-Foo');

is(minil('new', '--username=anonymous', '--email=foo@example.com','Acme::Foo'), 0);
ok(-f 'Acme-Foo/Build.PL');
ok(-f 'Acme-Foo/.travis.yml');
ok(-f 'Acme-Foo/t/00_compile.t');
{
    local $ENV{PERL_MM_USE_DEFAULT} = 1;
    local $ENV{PERL_MINILLA_SKIP_CHECK_CHANGE_LOG} = 1;
    local $ENV{FAKE_RELEASE} = 1;
    my $guard = pushd('Acme-Foo');
    is(minil('migrate'), 0);
    is(minil('build'), 0);
    is(minil('test'), 0);
    is(minil('dist'), 0);
    if (eval "require CPAN::Uploader; 1") {
        is(minil('release', '--dry-run'), 0);
    } else {
        diag "CPAN::Upoader is not installed?, skip releng tests";
    }
}

rmtree('Acme-Foo');

done_testing;

sub minil {
    system($^X, "-I$lib", $bin, @_);
}
