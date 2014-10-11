use strict;
use warnings;
use utf8;
use Test::More;
use t::Util;

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

subtest 'develop deps' => sub {
    my $guard = pushd(tempdir());

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

    my $resources_url_of_meta_json_ok = sub {
        my $git_conf_url = shift;

        my $guard = pushd(tempdir());

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
        my $resources = $meta_json->{resources};

        my $https_url = '';
        is $resources->{bugtracker}->{web}, 'https://github.com/tokuhirom/Minilla/issues';
        is $resources->{homepage}, 'https://github.com/tokuhirom/Minilla';
        is $resources->{repository}->{url}, 'git://github.com/tokuhirom/Minilla.git';
        is $resources->{repository}->{web}, 'https://github.com/tokuhirom/Minilla'
    };

    subtest 'when remote of origin url is https protocol' => sub {
        my $git_conf_url = 'https://github.com/tokuhirom/Minilla.git';
        $resources_url_of_meta_json_ok->($git_conf_url);
    };
    subtest 'when remote of origin url is git protocol' => sub {
        my $git_conf_url = 'git://github.com/tokuhirom/Minilla.git';
        $resources_url_of_meta_json_ok->($git_conf_url);
    };
    subtest 'when remote of origin url is ssh' => sub {
        my $git_conf_url = 'git@github.com:tokuhirom/Minilla.git';
        $resources_url_of_meta_json_ok->($git_conf_url);
    };
};


done_testing;

