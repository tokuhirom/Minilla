use strict;
use warnings;
use utf8;
use Test::More;
use Test::Requires 'Version::Next';
use CPAN::Meta;
use Minilla;

use lib "t/lib";
use Util;
use Minilla::CLI;
use Minilla::CLI::Prepare;
use Minilla::Profile::ModuleBuild;

subtest 'prepare an explicitly selected version' => sub {
    my $guard = pushd(tempdir(CLEANUP => 1));

    Minilla::Profile::ModuleBuild->new(
        author => 'hoge',
        dist => 'Acme-Foo',
        module => 'Acme::Foo',
        path => 'Acme/Foo.pm',
        version => 'v1.2.2',
    )->generate();
    write_minil_toml('Acme-Foo');
    spew('Changes', <<'EOF');
Revision history for Perl extension Acme-Foo

{{$NEXT}}
    - Add a release feature

v1.2.2 2026-10-01T00:00:00Z
    - Previous release
EOF
    git_init_add_commit();

    Minilla::CLI->run('prepare', 'v1.2.3');

    like slurp('lib/Acme/Foo.pm'), qr/our \$VERSION = "v1\.2\.3"/,
        'updates the module version';
    my $meta = CPAN::Meta->load_file('META.json', { lazy_validation => 0 });
    is $meta->version, 'v1.2.3',
        'regenerates META.json with the selected version';
    is $meta->generated_by, "Minilla/$Minilla::VERSION",
        'records Minilla as the META.json generator';
    like(
        slurp('Changes'),
        qr{
            \{\{\$NEXT\}\}\n\n
            v1\.2\.3\ \d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ\n
            \ \ \ \ -\ Add\ a\ release\ feature\n\n
            v1\.2\.2\ 2026-10-01T00:00:00Z
        }x,
        'moves pending entries into a prepared release below an empty NEXT section',
    );
    my @commits = split /\n/, `git rev-list --all`;
    is scalar(@commits), 1, 'does not create a commit';
    is `git tag --list`, '', 'does not create a tag';
    is_deeply [glob('*.tar.gz')], [], 'does not create a distribution archive';
};

subtest 'prepare without managed Changes' => sub {
    my $guard = pushd(tempdir(CLEANUP => 1));

    Minilla::Profile::ModuleBuild->new(
        author => 'hoge',
        dist => 'Acme-Foo',
        module => 'Acme::Foo',
        path => 'Acme/Foo.pm',
        version => '0.01',
    )->generate();
    spew('minil.toml', qq{name = "Acme-Foo"\nmanage_changes = false\n});
    unlink 'Changes' or die "Cannot remove Changes: $!";
    git_init_add_commit();

    Minilla::CLI::Prepare->run('0.02');

    like slurp('lib/Acme/Foo.pm'), qr/our \$VERSION = "0\.02"/,
        'updates the version without requiring Changes';
    ok !-e 'Changes', 'does not create Changes';
};

subtest 'prepare with interactive version selection' => sub {
    my $guard = pushd(tempdir(CLEANUP => 1));

    Minilla::Profile::ModuleBuild->new(
        author => 'hoge',
        dist => 'Acme-Foo',
        module => 'Acme::Foo',
        path => 'Acme/Foo.pm',
        version => '0.01',
    )->generate();
    write_minil_toml('Acme-Foo');
    git_init_add_commit();
    cmd('git', 'tag', '0.01');

    local $ENV{PERL_MM_USE_DEFAULT} = 1;
    Minilla::CLI::Prepare->run();

    like slurp('lib/Acme/Foo.pm'), qr/our \$VERSION = "0\.02"/,
        'accepts the prompted default next version';
    like slurp('Changes'), qr/\{\{\$NEXT\}\}\n\n0\.02 /,
        'prepares Changes for the interactively selected version';
};

done_testing;
