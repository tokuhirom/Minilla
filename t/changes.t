use strict;
use warnings;
use utf8;
use Test::More;

use Minilla::Changes;

subtest 'prepared release with an empty NEXT section' => sub {
    my $content = <<'EOF';
Revision history for Perl extension Hoge

{{$NEXT}}

v1.2.3 2025-12-17T15:08:28Z
    - Hogehoge
EOF

    ok Minilla::Changes::is_prepared($content, 'v1.2.3'),
        'prepared release detected';
};

subtest 'release version is not prepared' => sub {
    my $content = <<'EOF';
{{$NEXT}}
    - Next release

v1.2.2 2025-11-01T00:00:00Z
    - Previous release
EOF

    ok !Minilla::Changes::is_prepared($content, 'v1.2.3'),
        'a previous release heading does not count as prepared';
};

done_testing;
