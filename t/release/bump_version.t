use strict;
use warnings;
use utf8;
use Test::More;
use Test::Output qw(stderr_like);

use Minilla::Release::BumpVersion;

{
    package Local::Project;
    sub new { bless {}, shift }
    sub metadata { shift }
    sub version { '0.01' }
}

subtest 'noninteractive version selection' => sub {
    my $project = Local::Project->new;
    local *STDIN;
    open STDIN, '<', \'' or die "Cannot redirect standard input: $!";
    local $ENV{PERL_MM_USE_DEFAULT} = 1;
    no warnings 'redefine';
    local *Minilla::Release::BumpVersion::prompt = sub { die "Unexpected prompt\n" };
    local *Minilla::Release::BumpVersion::default_new_version = sub {
        die "Unexpected automatic version selection\n";
    };
    local *Minilla::Release::BumpVersion::bump_version = sub {
        die "Unexpected version update\n";
    };

    my $error;
    stderr_like {
        eval { Minilla::Release::BumpVersion->run($project, { dry_run => 0 }) };
        $error = $@;
    } qr/A version is required.*minil prepare VERSION/,
        'missing version reports how to prepare a noninteractive release';
    isa_ok $error, 'Minilla::Error::CommandExit';

    Minilla::Release::BumpVersion->run($project, { version => '0.02', dry_run => 1 });
    pass 'an explicit compatible version needs no prompt';

    Minilla::Release::BumpVersion->run($project, { skip_prepare => 1, dry_run => 1 });
    pass 'skip_prepare does not require a new version';

    stderr_like {
        eval {
            Minilla::Release::BumpVersion->run($project, { version => 'v1.2.3', dry_run => 0 });
        };
        $error = $@;
    } qr/version format doesn't match.*0\.01 -> v1\.2\.3/,
        'format mismatch fails instead of asking for confirmation';
    isa_ok $error, 'Minilla::Error::CommandExit';

    stderr_like {
        eval {
            Minilla::Release::BumpVersion->run($project, { version => 'invalid', dry_run => 0 });
        };
        $error = $@;
    } qr/version 'invalid' is invalid/, 'explicit versions are still validated';
    isa_ok $error, 'Minilla::Error::CommandExit';
};

subtest 'interactive version selection and confirmation' => sub {
    my $project = Local::Project->new;
    no warnings 'redefine';
    local *Minilla::Release::BumpVersion::is_interactive = sub { 1 };
    local *Minilla::Release::BumpVersion::default_new_version = sub { '0.02' };
    local *Minilla::Release::BumpVersion::prompt = sub {
        is_deeply [@_], ['Next Release?', '0.02'], 'offers the default next version';
        return '0.02';
    };
    Minilla::Release::BumpVersion->run($project, { dry_run => 1 });

    local *Minilla::Release::BumpVersion::prompt = sub {
        like $_[0], qr/Continue the release with this version/, 'asks to confirm a format change';
        return 'y';
    };
    Minilla::Release::BumpVersion->run($project, { version => 'v1.2.3', dry_run => 1 });
};

subtest 'version_format' => sub {
    my @tests = (
        ['0.11'       => 'decimal',    'decimal v0'],
        ['0.11_33'    => 'decimal',    'decimal alpha'],
        ['1.234567'   => 'decimal',    'decimal'],
        ['v0.2.3'     => 'dotted',     'dotted v0'],
        ['v1.2.3'     => 'dotted',     'dotted'],
        ['v1.2.3_1'   => 'dotted',     'dotted alpha'],
        ['v1.2'       => 'dotted',     'dotted without patch'],
        ['v1.2_1'     => 'dotted',     'dotted without patch with alpha'],
        ['0.2.3'      => 'lax dotted', 'lzx dotted v0'],
        ['1.2.3'      => 'lax dotted', 'lax dotted'],
        ['1.2.3_2'    => 'lax dotted', 'lax dotted with alpha'],

        ['unknown'    => 'unknown', 'unknown'],
        ['01.3333'    => 'unknown', 'invalid prefixed zero'],
        ['v01.33.22'  => 'unknown', 'invalid prefixed zero with dotted'],
        ['v1.2.3_dev' => 'unknown', 'invalid alpha'],
    );

    for my $t (@tests) {
        my ($ver, $expect, $desc) = @$t;
        is(Minilla::Release::BumpVersion::version_format($ver), $expect, $desc);
    }
};

done_testing;
