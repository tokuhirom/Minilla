use strict;
use warnings;
use utf8;
use Test::More;

use Minilla::Release::BumpVersion;

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
