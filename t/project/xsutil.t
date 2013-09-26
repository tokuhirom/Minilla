use strict;
use warnings;
use utf8;
use Test::More;
use t::Util;

use CPAN::Meta;

use Minilla::Profile::Default;
use Minilla::Project;
use Minilla::Git;

subtest 'No xsutil' => sub {
    my $guard = pushd( tempdir() );

    make_profile();
    write_minil_toml(
        {   name   => 'Acme-Foo',
        }
    );
    git_init_add_commit();

    my $project = Minilla::Project->new();
    is $project->use_xsutil, 0;
};


subtest 'Use XSUtil with default value' => sub {
    my $guard = pushd( tempdir() );

    make_profile();
    write_minil_toml(
        {   name   => 'Acme-Foo',
            XSUtil => {},
        }
    );
    git_init_add_commit();

    my $project = Minilla::Project->new();
    is $project->use_xsutil, 1;
    is $project->needs_compiler_c99, 0;
    is $project->needs_compiler_cpp, 0;
    is $project->generate_ppport_h, 0;
    is $project->generate_xshelper_h, 0;
    is $project->cc_warnings, 0;
};

subtest 'Use XSUtil with specify value' => sub {
    my $guard = pushd( tempdir() );

    make_profile();
    write_minil_toml(
        {   name   => 'Acme-Foo',
            XSUtil => {
                needs_compiler_c99 => 1,
                needs_compiler_cpp => 1,
                generate_ppport_h => 1,
                generate_xshelper_h => 1,
                cc_warnings => 1,
            },
        }
    );
    git_init_add_commit();

    my $project = Minilla::Project->new();
    is $project->use_xsutil, 1;
    is $project->needs_compiler_c99, 1;
    is $project->needs_compiler_cpp, 1;
    is $project->generate_ppport_h, 1;
    is $project->generate_xshelper_h, 1;
    is $project->cc_warnings, 1;
};

done_testing;

sub make_profile {
    my $profile = Minilla::Profile::Default->new(
        author  => 'hoge',
        dist    => 'Acme-Foo',
        path    => 'Acme/Foo.pm',
        module  => 'Acme::Foo',
        version => '0.01',
    );
    $profile->generate();
}
