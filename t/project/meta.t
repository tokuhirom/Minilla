use strict;
use warnings;
use utf8;
use Test::More;
use lib "t/lib";
use Util;

use Test::More;

use File::Temp qw(tempdir);
use File::pushd;
use File::Basename qw(dirname);
use File::Path qw(mkpath);
use Minilla::Profile::Default;
use Minilla::Project;
use CPAN::Meta::Validator;
use File::Spec::Functions qw(catdir);
use JSON qw(decode_json);
use version;

subtest 'develop deps' => sub {
    my $guard = pushd(tempdir(CLEANUP => 1));

    my $profile = Minilla::Profile::Default->new(
        author => 'foo',
        dist => 'Acme-Foo',
        path => 'Acme/Foo.pm',
        suffix => 'Foo',
        module => 'Acme::Foo',
        version => '0.01',
        email => 'foo@example.com',
    );
    $profile->generate();
    spew('cpanfile', 'requires "Moose";');
    write_minil_toml('Acme-Foo');

    git_init_add_commit();

    Minilla::Project->new()->regenerate_files;

    like(slurp('META.json'), qr!Test::Pod!, 'Modules required by release testing is noteded in META.json');
    my $meta = CPAN::Meta->load_file('META.json');
    is_deeply(
        $meta->{prereqs}->{runtime}->{requires},
        {
            'perl'  => '5.008001',
            'Moose' => '0'
        }
    );

    is_deeply(
        $meta->no_index,
        {
            directory => [qw/t xt inc share eg examples author builder/],
        },
    );

    my $validator = CPAN::Meta::Validator->new($meta->as_struct);
    ok($validator->is_valid) or diag join( "\n", $validator->errors );
};

subtest 'resources' => sub {

    my $prepare_meta_json_resources = sub {
        my $git_conf_url = shift;

        my $guard = pushd(tempdir(CLEANUP => 1));

        my $profile = Minilla::Profile::Default->new(
            author => 'Tokuhiro Matsuno',
            dist => 'Acme-Foo',
            path => 'Acme/Foo.pm',
            suffix => 'Foo',
            module => 'Acme::Foo',
            version => '0.01_01',
            email => 'tokuhirom@example.com',
        );
        $profile->generate();
        write_minil_toml('Acme-Foo');

        git_init_add_commit();

        # Add remote information
        {
            open my $fh, '>>', catdir('.git', 'config');
            print $fh <<"...";
[remote "origin"]
    url = $git_conf_url
    fetch = +refs/heads/*:refs/remotes/origin/*
...
        }

        my $project = Minilla::Project->new();
        my $work_dir = $project->work_dir();
        $work_dir->build;

        open my $fh, '<', 'META.json';
        my $meta_json = decode_json(do { local $/; <$fh> });
        return $meta_json->{resources};
    };

    subtest 'github' => sub {
        my $resources_url_of_meta_json_ok = sub {
            my $git_conf_url = shift;
            my $resources = $prepare_meta_json_resources->($git_conf_url);
            is $resources->{bugtracker}->{web}, 'https://github.com/tokuhirom/Minilla/issues';
            is $resources->{homepage}, 'https://github.com/tokuhirom/Minilla';
            is $resources->{repository}->{url}, 'git://github.com/tokuhirom/Minilla.git';
            is $resources->{repository}->{web}, 'https://github.com/tokuhirom/Minilla'
        };

        subtest 'when remote of origin url is https protocol' => sub {
            my $git_conf_url = 'https://github.com/tokuhirom/Minilla.git';
            $resources_url_of_meta_json_ok->($git_conf_url);
        };
        subtest 'when remote of origin url is https protocol with port' => sub {
            my $git_conf_url = 'https://github.com:443/tokuhirom/Minilla.git';
            $resources_url_of_meta_json_ok->($git_conf_url);
        };
        subtest 'when remote of origin url is git protocol' => sub {
            my $git_conf_url = 'git://github.com/tokuhirom/Minilla.git';
            $resources_url_of_meta_json_ok->($git_conf_url);
        };
        subtest 'when remote of origin url is git protocol without scheme' => sub {
            my $git_conf_url = 'git@github.com:tokuhirom/Minilla.git';
            $resources_url_of_meta_json_ok->($git_conf_url);
        };
        subtest 'when remote of origin url is git protocol with port' => sub {
            my $git_conf_url = 'git://github.com:9418/tokuhirom/Minilla.git';
            $resources_url_of_meta_json_ok->($git_conf_url);
        };
        subtest 'when remote of origin url is ssh' => sub {
            my $git_conf_url = 'ssh://git@github.com/tokuhirom/Minilla.git';
            $resources_url_of_meta_json_ok->($git_conf_url);
        };
        subtest 'when remote of origin url is ssh with port' => sub {
            my $git_conf_url = 'ssh://git@github.com:22/tokuhirom/Minilla.git';
            $resources_url_of_meta_json_ok->($git_conf_url);
        };
    };

    subtest 'not github' => sub {
        my $resources_url_of_meta_json_ok = sub {
            my ($git_conf_url, $expected_url) = @_;
            my $resources = $prepare_meta_json_resources->($git_conf_url);
            is $resources->{repository}->{url}, $expected_url
                or diag explain $resources;
        };

        subtest 'when remote of origin url is https protocol' => sub {
            my $git_conf_url = 'https://git.local/tokuhirom/Minilla.git';
            $resources_url_of_meta_json_ok->($git_conf_url, $git_conf_url);
        };
        subtest 'when remote of origin url is https protocol with port' => sub {
            my $git_conf_url = 'https://git.local:443/tokuhirom/Minilla.git';
            $resources_url_of_meta_json_ok->($git_conf_url, $git_conf_url);
        };
        subtest 'when remote of origin url is git protocol' => sub {
            my $git_conf_url = 'git://git.local/tokuhirom/Minilla.git';
            $resources_url_of_meta_json_ok->($git_conf_url, $git_conf_url);
        };
        subtest 'when remote of origin url is git protocol without scheme' => sub {
            my $git_conf_url = 'git@git.local:tokuhirom/Minilla.git';
            $resources_url_of_meta_json_ok->($git_conf_url, "git://git.local/tokuhirom/Minilla.git");
        };
        subtest 'when remote of origin url is git protocol with port' => sub {
            my $git_conf_url = 'git://git.local:9418/tokuhirom/Minilla.git';
            $resources_url_of_meta_json_ok->($git_conf_url, $git_conf_url);
        };
        subtest 'when remote of origin url is ssh' => sub {
            my $git_conf_url = 'ssh://git@git.local/tokuhirom/Minilla.git';
            $resources_url_of_meta_json_ok->($git_conf_url, $git_conf_url);
        };
        subtest 'when remote of origin url is ssh with port' => sub {
            my $git_conf_url = 'ssh://git@git.local:22/tokuhirom/Minilla.git';
            $resources_url_of_meta_json_ok->($git_conf_url, $git_conf_url);
        };
    };

    subtest 'manual' => sub {
        my $guard = pushd(tempdir(CLEANUP => 1));

        my $profile = Minilla::Profile::Default->new(
            author => 'foo',
            dist => 'Acme-Foo',
            path => 'Acme/Foo.pm',
            suffix => 'Foo',
            module => 'Acme::Foo',
            version => '0.01',
            email => 'foo@example.com',
        );
        $profile->generate();

        write_minil_toml({
            name       => 'Acme-Foo',
            resources  => {
                homepage   => 'http://www.acme.example/foo',
                bugtracker => { web => 'http://www.acme.example/foo/bugs' },
            },
        });

        git_init_add_commit();

        # Add remote information
        {
            my $git_conf_url = 'https://github.com/icklekitten/Acme-Foo.git';
            open my $fh, '>>', catdir('.git', 'config');
            print $fh <<"...";
[remote "origin"]
    url = $git_conf_url
    fetch = +refs/heads/*:refs/remotes/origin/*
...
        }

        Minilla::Project->new()->regenerate_files;

        my $meta = CPAN::Meta->load_file('META.json');

        is_deeply(
            $meta->resources,
            {
                'bugtracker' => {
                    'web' => 'http://www.acme.example/foo/bugs'
                },
                'homepage' => 'http://www.acme.example/foo',
                'repository' => {
                    'type'  => 'git',
                    'url'   => 'git://github.com/icklekitten/Acme-Foo.git',
                    'web'   => 'https://github.com/icklekitten/Acme-Foo'
                }
            },
        );

        my $validator = CPAN::Meta::Validator->new($meta->as_struct);
        ok($validator->is_valid) or diag join( "\n", $validator->errors );
    };
};

subtest 'Metadata' => sub {
    my $guard = pushd(tempdir(CLEANUP => 1));

    my $profile = Minilla::Profile::Default->new(
        author => 'foo',
        dist => 'Acme-Foo',
        path => 'Acme/Foo.pm',
        suffix => 'Foo',
        module => 'Acme::Foo',
        version => '0.01',
        email => 'foo@example.com',
    );
    $profile->generate();
    write_minil_toml({
        name => 'Acme-Foo',
        Metadata => {
            x_deprecated => 1,
            x_static_install => 1,
        },
    });

    git_init_add_commit();

    Minilla::Project->new()->regenerate_files;

    my $meta = CPAN::Meta->load_file('META.json');
    ok $meta->{x_static_install};
    ok $meta->{x_deprecated};
};

subtest perl_version => sub {
    my $guard = pushd(tempdir(CLEANUP => 1));

    my $profile = Minilla::Profile::Default->new(
        author => 'foo',
        dist => 'Acme-Foo',
        path => 'Acme/Foo.pm',
        suffix => 'Foo',
        module => 'Acme::Foo',
        version => '0.01',
        email => 'foo@example.com',
    );
    $profile->generate();
    write_minil_toml('Acme-Foo');
    my $content = slurp_raw 'lib/Acme/Foo.pm';
    $content =~ s/use 5.008001/use v5.20/;
    spew 'lib/Acme/Foo.pm', $content;
    git_init_add_commit();
    Minilla::Project->new()->regenerate_files;
    my $meta = CPAN::Meta->load_file('META.json');
    my $version = version->parse($meta->{prereqs}{runtime}{requires}{perl});
    ok $version == version->declare('v5.20.0');
};


done_testing;

