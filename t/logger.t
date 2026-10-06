use strict;
use warnings;
use Test::More;
use Test::Output;

use Minilla;
use Minilla::Logger;

local $Minilla::Logger::COLOR = 0;

output_is(
    sub { infof("Info: %s\n", "message") },
    '',
    "Info: message\n",
    'info logs are written to standard error',
);

{
    local $Minilla::DEBUG = 1;
    output_is(
        sub { debugf("Debug: %s\n", "message") },
        '',
        "Debug: message\n",
        'debug logs are written to standard error',
    );
}

output_is(
    sub { warnf("Warning: %s\n", "message") },
    '',
    "Warning: message\n",
    'warning logs are written to standard error',
);

done_testing;
