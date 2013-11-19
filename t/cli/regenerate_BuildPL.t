use strict;
use warnings;
use utf8;
use Test::More;
use t::Util;
use Test::Requires 'Version::Next', 'CPAN::Uploader';
use Minilla::CLI::Build;
use Minilla::CLI::Dist;
use Minilla::CLI::New;
use Minilla::CLI::Release;
use Minilla::CLI::Test;

sub regenerate_BuildPL_test {
    my ($cli_class, %opt) = @_;
    my $fork  = $opt{fork};
    my $repo  = $opt{repo};

    my $guard = pushd(tempdir());
    Minilla::CLI::New->run("Acme::Foo");

    {
        my $guard2 = pushd("Acme-Foo");
        mkdir "builder";
        spew "builder/MyBuilder.pm", q(
            package builder::MyBuilder;
            use base 'Module::Build';
            1;
        );

        write_minil_toml({
            name  => 'Acme-Foo',
            build => { build_class => "builder::MyBuilder" }
        });

        git_add;
        git_remote('add', 'origin', "file://$repo") if $repo;

        if ($fork) {
            my $pid = fork;
            die "fork failed" unless defined $pid;
            if ($pid == 0) {
                $cli_class->run;
                die "never reach here";
            }
            waitpid $pid, 0;
        } else {
            $cli_class->run;
        }

        like slurp("Build.PL"), qr/use\s+builder::MyBuilder/,
            "$cli_class\->run should regenerate Build.PL";
    }
}

{
    my $repo = tempdir();
    { my $guard = pushd($repo); cmd('git', 'init', '--bare'); }
    local $ENV{PERL_MM_USE_DEFAULT} = 1;
    local $ENV{PERL_MINILLA_SKIP_CHECK_CHANGE_LOG} = 1;
    local $ENV{FAKE_RELEASE} = 1;
    regenerate_BuildPL_test "Minilla::CLI::Release", fork => 0, repo => $repo;
}
regenerate_BuildPL_test "Minilla::CLI::Build", fork => 0;
regenerate_BuildPL_test "Minilla::CLI::Dist",  fork => 0;
regenerate_BuildPL_test "Minilla::CLI::Test",  fork => 1;

done_testing;
