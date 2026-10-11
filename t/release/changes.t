use strict;
use warnings;
use utf8;
use Test::More;
use File::Temp qw(tempdir);
use File::pushd;
use Test::Output qw(stderr_like);

use Minilla::Release::CheckChanges;
use Minilla::Release::RewriteChanges;
use Minilla::Util qw(slurp_raw spew_raw);

{
    package Local::Project;

    sub new {
        my ($class, $version) = @_;
        bless { version => $version }, $class;
    }

    sub version { shift->{version} }
}

subtest 'prepared Changes passes release checks and remains unchanged' => sub {
    my $guard = pushd(tempdir(CLEANUP => 1));
    my $project = Local::Project->new('v1.2.3');
    my $content = <<'EOF';
Revision history for Perl extension Hoge

{{$NEXT}}

v1.2.3 2025-12-17T15:08:28Z
    - Hogehoge
EOF
    spew_raw('Changes', $content);

    Minilla::Release::CheckChanges->run($project, {});
    Minilla::Release::RewriteChanges->run($project, {});

    is slurp_raw('Changes'), $content,
        'release does not duplicate the prepared version or change its timestamp';
};

subtest 'noninteractive Changes editing is skipped' => sub {
    my $guard = pushd(tempdir(CLEANUP => 1));
    my $project = Local::Project->new('0.02');
    local *STDIN;
    open STDIN, '<', \'' or die "Cannot redirect standard input: $!";
    no warnings 'redefine';
    local *Minilla::Release::CheckChanges::prompt = sub { die "Unexpected prompt\n" };
    local *Minilla::Release::CheckChanges::edit_file = sub { die "Unexpected editor\n" };
    local $ENV{PERL_MINILLA_SKIP_CHECK_CHANGE_LOG} = 0;
    local $ENV{PERL_MM_USE_DEFAULT} = 1;

    for my $content (
        "Revision history\n",
        "    {{\$NEXT}}\n",
        "{{\$NEXT}} extra text\n",
        "{{\$NEXT}}\n\n",
    ) {
        spew_raw('Changes', $content);
        stderr_like {
            Minilla::Release::CheckChanges->run($project, {});
        } qr/Skipping Changes editing because standard input is not a terminal/,
            'reports the skipped editing step without prompting';
        is slurp_raw('Changes'), $content, 'does not edit Changes';
    }

    spew_raw('Changes', "{{\$NEXT}}\n    - A change\n");
    stderr_like {
        Minilla::Release::CheckChanges->run($project, {});
    } qr/\A\z/, 'valid pending Changes still passes without warnings';
};

subtest 'interactive Changes editing remains available' => sub {
    my $guard = pushd(tempdir(CLEANUP => 1));
    my $project = Local::Project->new('0.02');
    spew_raw('Changes', "{{\$NEXT}}\n\n");
    no warnings 'redefine';
    local *Minilla::Release::CheckChanges::is_interactive = sub { 1 };
    local *Minilla::Release::CheckChanges::prompt = sub {
        is_deeply [@_], ['Edit file?', 'y'], 'asks to edit with the existing default';
        return 'y';
    };
    local *Minilla::Release::CheckChanges::edit_file = sub {
        is $_[0], 'Changes', 'opens Changes in the editor';
        spew_raw('Changes', "{{\$NEXT}}\n    - A change\n");
    };
    Minilla::Release::CheckChanges->run($project, {});
    like slurp_raw('Changes'), qr/A change/, 'rechecks the edited Changes';
};

done_testing;
