use strict;
use warnings;
use utf8;
use Test::More;
use Test::Requires 'Version::Next', 'CPAN::Uploader';
use lib "t/lib";
use Util;
use Minilla::Profile::ModuleBuild;
use Minilla::CLI::Release;

my $repo = tempdir(CLEANUP => 1);
{
    my $guard = pushd($repo);
    cmd('git', 'init', '--bare');
}

my $guard = pushd(tempdir(CLEANUP => 1));

Minilla::Profile::ModuleBuild->new(
    author => 'hoge',
    dist => 'Acme-Foo',
    module => 'Acme::Foo',
    path => 'Acme/Foo.pm',
    version => '1.00',
)->generate();

spew("t/TestModule.pm", <<'___');
package TestModule;
our $VERSION = '0.01';
1;
___
write_minil_toml('Acme-Foo');
git_init_add_commit();
git_remote('add', 'origin', "file://$repo");

{
    local $ENV{PERL_MM_USE_DEFAULT} = 1;
    local $ENV{PERL_MINILLA_SKIP_CHECK_CHANGE_LOG} = 1;
    local $ENV{FAKE_RELEASE} = 1;
    Minilla::CLI::Release->run();

    my $content = slurp "t/TestModule.pm";
    my $expect = q|our $VERSION = '0.01';|;
    like $content, qr/\Q$expect/;
}

done_testing;

