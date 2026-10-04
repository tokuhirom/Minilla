use strict;
use warnings;
use utf8;
use Test::More;
use File::Temp qw(tempdir);
use File::pushd;
use Time::Piece;

use Minilla::Util qw(slurp_raw spew_raw);
use Minilla::WorkDir;

{
    package Local::Project;

    sub new {
        my ($class, $version) = @_;
        bless { version => $version }, $class;
    }

    sub files { [] }
    sub version { shift->{version} }
}

sub work_dir {
    my ($version, $time) = @_;
    Minilla::WorkDir->new(
        project => Local::Project->new($version),
        dir => tempdir(CLEANUP => 1),
        cleanup => 0,
        defined $time ? (changes_time => $time) : (),
    );
}

subtest 'prepared release keeps its recorded timestamp' => sub {
    my $work_dir = work_dir('v1.2.3');
    my $guard = pushd($work_dir->dir);
    spew_raw('Changes', <<'EOF');
Revision history for Perl extension Hoge

{{$NEXT}}

v1.2.3 2025-12-17T15:08:28Z
    - Hogehoge
EOF

    $work_dir->_rewrite_changes();

    is slurp_raw('Changes'), <<'EOF', 'only the NEXT marker and blank line are removed';
Revision history for Perl extension Hoge

v1.2.3 2025-12-17T15:08:28Z
    - Hogehoge
EOF
};

subtest 'pending changes keep the existing behavior' => sub {
    my $time = Time::Piece->strptime('2026-10-03T12:34:56Z', '%Y-%m-%dT%H:%M:%SZ');
    my $work_dir = work_dir('v1.2.3', $time);
    my $guard = pushd($work_dir->dir);
    spew_raw('Changes', <<'EOF');
{{$NEXT}}
    - Unreleased change

v1.2.3 2025-12-17T15:08:28Z
    - Released change
EOF

    $work_dir->_rewrite_changes();

    is slurp_raw('Changes'), <<'EOF', 'the NEXT marker is rewritten as before';
v1.2.3 2026-10-03T12:34:56Z
    - Unreleased change

v1.2.3 2025-12-17T15:08:28Z
    - Released change
EOF
};

subtest 'unprepared release keeps the existing behavior' => sub {
    my $time = Time::Piece->strptime('2026-10-03T12:34:56Z', '%Y-%m-%dT%H:%M:%SZ');
    my $work_dir = work_dir('v1.2.3', $time);
    my $guard = pushd($work_dir->dir);
    spew_raw('Changes', <<'EOF');
{{$NEXT}}
    - Hogehoge
EOF

    $work_dir->_rewrite_changes();

    is slurp_raw('Changes'), <<'EOF', 'the NEXT marker is replaced with version and build time';
v1.2.3 2026-10-03T12:34:56Z
    - Hogehoge
EOF
};

done_testing;
