use strict;
use warnings;

if (@ARGV && $ARGV[0] eq '--output-helper') {
    print "Child output\n";
    print STDERR "Child error\n";
    exit;
}

use Test::More;
use Test::Output qw(output_from output_is);
use JSON::PP qw(decode_json);
use ExtUtils::MakeMaker qw(prompt);

use lib 't/lib';
use Util;
use Minilla::CLI;
use Minilla::Profile::Default;

{
    no warnings 'redefine';
    local $ENV{PERL_MM_USE_DEFAULT} = 1;
    local *Minilla::CLI::New::run = sub {
        print "Direct output\n";
        print STDERR "Original standard error\n";
        cmd($^X, File::Spec->rel2abs($0), '--output-helper');
        prompt('Continue?', 'n');
        Minilla::Logger::slog({ event => 'result' });
    };
    my ($stdout, $stderr) = output_from(sub { Minilla::CLI->run('new') });
    is($stdout, "{\"event\":\"result\"}\n", 'only slog writes to standard output');
    like($stderr, qr/^Direct output$/m, 'direct output goes to standard error');
    like($stderr, qr/^Original standard error$/m, 'standard error is preserved');
    like($stderr, qr/^Child output$/m, 'child standard output goes to standard error');
    like($stderr, qr/^Child error$/m, 'child standard error is preserved');
    like($stderr, qr/^Continue\? \[n\] n$/m, 'prompts go to standard error');

    output_is(
        sub { print "Restored output\n" },
        "Restored output\n", '',
        'standard output is restored after command execution',
    );
}

{
    no warnings 'redefine';
    local *Minilla::CLI::_run = sub {
        print "Output before exception\n";
        die "Unexpected failure\n";
    };
    my $error;
    output_is(
        sub {
            eval { Minilla::CLI->run('new') };
            $error = $@;
            print "Restored after exception\n";
        },
        "Restored after exception\n", "Output before exception\n",
        'standard output is restored when command execution throws',
    );
    is($error, "Unexpected failure\n", 'the original exception propagates');
}

{
    no warnings 'redefine';
    local *Minilla::CLI::New::run = sub {
        Minilla::Logger::errorf("Command failed\n");
    };
    output_is(
        sub { Minilla::CLI->run('new'); print "Restored after failure\n" },
        "Restored after failure\n", "Command failed\n",
        'standard output is restored after a command error',
    );
}

{
    no warnings 'redefine';
    local *Minilla::CLI::New::run = sub {
        my ($self, @args) = @_;
        if (@args) {
            Minilla::Logger::slog({ event => 'nested' });
        } else {
            Minilla::CLI->run('new', 'nested');
            print "Outer output\n";
            Minilla::Logger::slog({ event => 'outer' });
        }
    };
    output_is(
        sub { Minilla::CLI->run('new') },
        "{\"event\":\"nested\"}\n{\"event\":\"outer\"}\n", "Outer output\n",
        'nested CLI execution retains the original structured output stream',
    );
}

my $script = File::Spec->rel2abs('script/minil');
my $lib = File::Spec->rel2abs('lib');
{
    my $status;
    my ($stdout, $stderr) = output_from(sub {
        $status = system($^X, "-I$lib", $script, '--version');
    });
    is($status, 0, 'version command succeeds');
    is($stdout, '', 'version command does not use standard output');
    like($stderr, qr/^Minilla: \Q$Minilla::VERSION\E\n\z/, 'version goes to standard error');
}

for my $maker (qw(ModuleBuildTiny ExtUtilsMakeMaker ModuleBuild)) {
    subtest $maker => sub {
        if ($maker eq 'ModuleBuild' && !eval { require Module::Build; 1 }) {
            plan skip_all => 'Module::Build is not installed';
        }
        my $guard = pushd(tempdir(CLEANUP => 1));
        Minilla::Profile::Default->new(
            author => 'Minilla', email => 'minilla@example.com',
            dist => 'Acme-Foo', module => 'Acme::Foo',
            path => 'Acme/Foo.pm', suffix => 'Foo', version => '0.01',
        )->generate();
        write_minil_toml({
            name => 'Acme-Foo', module_maker => $maker, manage_changes => 0,
        });
        git_init();
        git_config(qw(user.name Minilla));
        git_config(qw(user.email minilla@example.com));
        git_add('.');
        Minilla::Project->new->regenerate_files();
        git_add('.');
        git_commit('-m', 'prepared release');

        local $ENV{MINILLA_DISABLE_WRITE_RELEASE_TEST} = 1;
        for my $args (
            ['--no-test', '--skip-prepare'],
            [],
        ) {
            my $status;
            my ($stdout, $stderr) = output_from(sub {
                $status = system(
                    $^X, "-I$lib", $script, '--no-auto-install', 'dist', @$args,
                );
            });
            is($status, 0, 'dist succeeds');
            is_deeply(
                decode_json($stdout), { dist => 'Acme-Foo-0.01.tar.gz' },
                'the entire standard output is the structured result',
            );
            is(scalar(() = $stdout =~ /\n/g), 1, 'standard output contains exactly one line');
            like($stderr, qr/Creating new 'Build' script|Generating .*Makefile/,
                'build configuration progress goes to standard error');
            if (!@$args) {
                like($stderr, qr/All tests successful/, 'test summary goes to standard error');
            }
        }
    };
}

done_testing;
