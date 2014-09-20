use strict;
use warnings;
use utf8;
use t::Util;

use Test::More;
use Test::Output;

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
    my $profile = Minilla::Profile::Default->new(
        author => 'bar',
        dist => 'Acme-Bar',
        path => 'Acme/Bar.pm',
        suffix => 'Bar',
        module => 'Acme::Bar',
        version => '0.01',
        email => 'bar@example.com',
    );

    subtest '=encoding utf-8' => sub {
        my $guard = pushd(tempdir());
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

    subtest '=encoding ShiftJIS' => sub {
        my $guard = pushd(tempdir());
        $profile->generate();

        my $pm = slurp('lib/Acme/Bar.pm');
        $pm =~ s/^=encoding.+$/=encoding ShiftJIS/m;
        $pm =~ s/it's (new \$module)/それは $1/i;
        spew_utf8('lib/Acme/Bar.pm', $pm);

        spew('cpanfile', 'requires "Moose";');
        write_minil_toml('Acme-Bar');

        git_init_add_commit();

        stderr_like { Minilla::Project->new()->regenerate_files } qr!Wide character!i;

        unlike(slurp_utf8('META.json'), qr!それは new \$module!, 'non-latin-1 characters mojibake because pod is UTF-8, and ShiftJIS not supported');

        my $meta = CPAN::Meta->load_file('META.json');

        my $validator = CPAN::Meta::Validator->new($meta->as_struct);
        ok($validator->is_valid) or diag join( "\n", $validator->errors );
    };

    my @utf8_enc_list = ('utf-8', 'UTF-8', 'UtF-8', 'utf8', 'UTF8', '  utf-8  ');

    for my $enc (@utf8_enc_list) {
        subtest "=encoding $enc" => sub {
            my $guard = pushd(tempdir());
            $profile->generate();

            my $pm = slurp('lib/Acme/Bar.pm');
            $pm =~ s/^=encoding.+$/=encoding $enc/m;
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
    }

    subtest '=encoding line not fount' => sub {
        my $guard = pushd(tempdir());
        $profile->generate();

        my $pm = slurp('lib/Acme/Bar.pm');
        $pm =~ s/^=encoding.+$//m;
        $pm =~ s/it's (new \$module)/それは $1/i;

        unlike($pm, qr!=encoding!, '=encoding line has been removed');

        spew_utf8('lib/Acme/Bar.pm', $pm);

        spew('cpanfile', 'requires "Moose";');
        write_minil_toml('Acme-Bar');

        git_init_add_commit();

        stderr_like { Minilla::Project->new()->regenerate_files } qr!Wide character!i;

        unlike(slurp_utf8('META.json'), qr!それは new \$module!, 'non-latin-1 characters mojibake because of no =encoding line');

        my $meta = CPAN::Meta->load_file('META.json');

        my $validator = CPAN::Meta::Validator->new($meta->as_struct);
        ok($validator->is_valid) or diag join( "\n", $validator->errors );
    };
};

done_testing;

