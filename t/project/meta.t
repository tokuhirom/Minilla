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

subtest 'abstract has non-latin-1 characters' => sub {
    my $guard = pushd(tempdir());

    my $profile = Minilla::Profile::Default->new(
        author => 'bar',
        dist => 'Acme-Bar',
        path => 'Acme/Bar.pm',
        suffix => 'Bar',
        module => 'Acme::Bar',
        version => '0.01',
        email => 'bar@example.com',
    );
    $profile->generate();

    my $pm = slurp('lib/Acme/Bar.pm');
    $pm =~ s/it's (new \$module)/それは $1/i;
    spew_utf8('lib/Acme/Bar.pm', $pm);

    spew('cpanfile', 'requires "Moose";');
    write_minil_toml('Acme-Bar');

    git_init_add_commit();

    Minilla::Project->new()->regenerate_files;

    like(slurp_utf8('META.json'), qr!それは new \$module!, 'non-latin-1 characters not mojibake');

    my $meta = CPAN::Meta->load_file('META.json');

    my $validator = CPAN::Meta::Validator->new($meta->as_struct);
    ok($validator->is_valid) or diag join( "\n", $validator->errors );
};

done_testing;

