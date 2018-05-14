use strict;
use warnings;
use utf8;
use Test::More;
use lib "t/lib";
use Util;

use Minilla;
use Minilla::Project;
use Minilla::CLI::New;
use CPAN::Meta;
use TOML qw(from_toml to_toml);

subtest basic => sub {
    my $guard = pushd(tempdir());
    Minilla::CLI::New->run('Acme::Foo');
    chdir "Acme-Foo";

    my ($config, $meta);
    $config = from_toml slurp("minil.toml");
    is $config->{static_install}, "auto";

    $meta = CPAN::Meta->load_file("META.json")->as_struct;
    is $meta->{x_static_install}, 1;

    $config->{static_install} = 0;
    spew("minil.toml", to_toml $config);
    Minilla::Project->new->regenerate_files;
    $meta = CPAN::Meta->load_file("META.json")->as_struct;
    is $meta->{x_static_install}, 0;

    $config->{static_install} = 1;
    spew("minil.toml", to_toml $config);
    Minilla::Project->new->regenerate_files;
    $meta = CPAN::Meta->load_file("META.json")->as_struct;
    is $meta->{x_static_install}, 1;
};

my $static_install = sub {
    my $sub = shift;
    my $guard = pushd(tempdir());
    Minilla::CLI::New->run('Acme::Foo');
    chdir "Acme-Foo";
    $sub->();
    git_add(".");
    Minilla::Project->new->regenerate_files;
    git_add(".");
    CPAN::Meta->load_file("META.json")->as_struct->{x_static_install};
};

subtest auto_detection => sub {
    my $test;

    $test = sub {
        mkdir "script";
        spew "script/foo", "#!perl\nprint 'hello'\n";
    };
    is $static_install->($test), 1;

    $test = sub {
        mkdir "share";
        spew "share/foo", "this is a share file";
    };
    is $static_install->($test), 1;

    $test = sub {
        my $config = from_toml slurp "minil.toml";
        $config->{module_maker} = "ExtUtilsMakeMaker";
        spew "minil.toml", to_toml $config;
    };
    is $static_install->($test), 1;

    $test = sub {
        mkdir "bin";
        spew "bin/foo", "#!perl\nprint 'hello'\n";
    };
    is $static_install->($test), 0;

    $test = sub {
        spew "lib/Acme/Foo.xs", "/* this is a xs code */\n";
    };
    is $static_install->($test), 0;

    $test = sub {
        my $config = from_toml slurp "minil.toml";
        $config->{requires_external_bin} = ["git"];
        spew "minil.toml", to_toml $config;
    };
    is $static_install->($test), 0;

    $test = sub {
        my $config = from_toml slurp "minil.toml";
        $config->{unsupported}{os} = ["MSWin32"];
        spew "minil.toml", to_toml $config;
    };
    is $static_install->($test), 0;

    $test = sub {
        my $config = from_toml slurp "minil.toml";
        $config->{build}{build_class} = 'builder::MyBuilder';
        spew "minil.toml", to_toml $config;
        mkdir "builder";
        spew "builder/MyBuilder", q{
            package builder::MyBuilder;
            use base 'Module::Build';
        };
    };
    is $static_install->($test), 0;

    $test = sub {
        spew "lib/Acme/Bar.pm.PL", "# this is a PL file\n";
    };
    is $static_install->($test), 0;

    $test = sub {
        my $config = from_toml slurp "minil.toml";
        $config->{PL_files}{"Bar.pm.PL"} = "lib/Acme/Bar.pm";
        $config->{module_maker} = "ModuleBuild";
        spew "minil.toml", to_toml $config;
        spew "Bar.pm.PL", "# this is a PL file\n";
    };
    is $static_install->($test), 0;
};

done_testing;
