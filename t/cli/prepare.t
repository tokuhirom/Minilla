use strict;
use warnings;
use utf8;
use Test::More;
use Test::Requires 'Version::Next';
use Test::Output qw(stderr_like);
use CPAN::Meta;
use Minilla;

use lib "t/lib";
use Util;
use Minilla::CLI;
use Minilla::CLI::Prepare;
use Minilla::Profile::ModuleBuild;

my $script = File::Spec->rel2abs('script/minil');
my $lib = File::Spec->rel2abs('lib');

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
    no warnings 'redefine';
    local *Minilla::Release::BumpVersion::is_interactive = sub { 1 };
    Minilla::CLI::Prepare->run();

    like slurp('lib/Acme/Foo.pm'), qr/our \$VERSION = "0\.02"/,
        'accepts the prompted default next version';
    like slurp('Changes'), qr/\{\{\$NEXT\}\}\n\n0\.02 /,
        'prepares Changes for the interactively selected version';
};

subtest 'noninteractive prepare requires a version and skips Changes editing' => sub {
    my $guard = pushd(tempdir(CLEANUP => 1));
    Minilla::Profile::ModuleBuild->new(
        author => 'hoge',
        dist => 'Acme-Foo',
        module => 'Acme::Foo',
        path => 'Acme/Foo.pm',
        version => '0.01',
    )->generate();
    write_minil_toml('Acme-Foo');
    spew('Changes', "{{\$NEXT}}\n\n");
    git_init_add_commit();

    local $ENV{PERL_MM_USE_DEFAULT} = 1;
    {
        local *STDIN;
        open STDIN, '<', File::Spec->devnull or die "Cannot redirect standard input: $!";
        no warnings 'redefine';
        local *Minilla::Release::BumpVersion::prompt = sub { die "Unexpected version prompt\n" };
        local *Minilla::Release::CheckChanges::prompt = sub { die "Unexpected Changes prompt\n" };
        local *Minilla::Release::CheckChanges::edit_file = sub { die "Unexpected editor\n" };

        my $original = slurp('lib/Acme/Foo.pm');
        my $error;
        stderr_like {
            eval { Minilla::CLI::Prepare->run() };
            $error = $@;
        } qr/A version is required/, 'missing version fails without a prompt';
        isa_ok $error, 'Minilla::Error::CommandExit';
        is slurp('lib/Acme/Foo.pm'), $original, 'missing version leaves the source unchanged';
        is slurp('Changes'), "{{\$NEXT}}\n\n", 'missing version leaves Changes unchanged';

        stderr_like {
            eval { Minilla::CLI::Prepare->run('') };
            $error = $@;
        } qr/version '' is invalid/, 'empty version fails without a prompt';
        isa_ok $error, 'Minilla::Error::CommandExit';
        is slurp('lib/Acme/Foo.pm'), $original, 'empty version leaves the source unchanged';
        is slurp('Changes'), "{{\$NEXT}}\n\n", 'empty version leaves Changes unchanged';

        stderr_like {
            Minilla::CLI::Prepare->run('0.02');
        } qr/Skipping Changes editing/, 'explicit version skips Changes editing';
        like slurp('lib/Acme/Foo.pm'), qr/our \$VERSION = "0\.02"/, 'updates the selected version';
        is(CPAN::Meta->load_file('META.json')->version, '0.02', 'regenerates metadata');
        like slurp('Changes'), qr/\{\{\$NEXT\}\}\n\n0\.02 /, 'still rewrites Changes';
    }

    for my $args ([], [''], ['0.03']) {
        my ($status, $message) = run_with_open_stdin(
            30,
            $^X, "-I$lib", $script, '--no-auto-install', 'prepare', @$args,
        );
        my $success = @$args && length $args->[0];
        is $status >> 8, $success ? 0 : 1,
            'CLI exits with the expected status while its input pipe stays open';
        like $message, $success ? qr/Skipping Changes editing/
            : @$args ? qr/version '' is invalid/ : qr/A version is required/,
            'CLI reports noninteractive handling';
        unlike $message, qr/Next Release\?|Edit file\?/, 'CLI does not prompt';
    }
    like slurp('lib/Acme/Foo.pm'), qr/our \$VERSION = "0\.03"/,
        'noninteractive CLI updates an explicitly selected version';
};

done_testing;
