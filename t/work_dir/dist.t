use strict;
use warnings;
use utf8;
use Test::More;

use t::Util;
use File::Spec::Functions qw(catfile);
use Archive::Tar;

use Minilla::Profile::Default;
use Minilla::Project;
use Minilla::Git;

subtest 'dist' => sub {
    my $guard = pushd(tempdir());

    my $profile = Minilla::Profile::Default->new(
        author => 'tokuhirom',
        dist => 'Acme-Foo',
        path => 'Acme/Foo.pm',
        suffix => 'Foo',
        module => 'Acme::Foo',
        version => '0.01',
        email => 'tokuhirom@example.com',
    );
    $profile->generate();
    write_minil_toml('Acme-Foo');
    spew 'empty.txt', '';

    git_init();
    git_add('.');
    git_config(qw(user.name tokuhirom));
    git_config(qw(user.email tokuhirom@example.com));
    Minilla::Project->new()->regenerate_files();
    git_commit('-m', 'initial import');
    ok -f 'Build.PL';

    git_config(qw(user.name Foo));
    git_config(qw(user.email foo@example.com));
    git_commit('--allow-empty', '-m', 'foo');
    git_config(qw(user.name Bar));
    git_config(qw(user.email bar@example.com));
    git_commit('--allow-empty', '-m', 'bar');
    git_commit('--allow-empty', '-m', 'bar2');

    my $work_dir = Minilla::Project->new()->work_dir;
    my $dist = $work_dir->dist();
    my $tar = Archive::Tar->new();
    $tar->read($dist);

    is_deeply(
        [sort $tar->list_files],
        [do {my %h;
            sort
            grep {!$h{$_}++}
            map  {
                my $x = "$_";
                $x =~ s!\\!/!g;
                "Acme-Foo-0.01/$x"
            }
            grep /\S/, split /\n/, $tar->get_content('Acme-Foo-0.01/MANIFEST')
        }],
        "Valid MANIFEST file was generated.",
    );
    like($tar->get_content('Acme-Foo-0.01/MANIFEST'), qr{^Build.PL$}sm, 'Contains Build.PL in MANIFEST');

    like($tar->get_content('Acme-Foo-0.01/MANIFEST'), qr{^empty.txt$}sm, 'Contains empty.txt in MANIFEST');
    ok($tar->contains_file('Acme-Foo-0.01/empty.txt'), 'Contains empty.txt in archive');
};

done_testing;
