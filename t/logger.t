use strict;
use warnings;
use Test::More;
use Test::Output;
use JSON::PP qw(decode_json);

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

{
    local $Minilla::Logger::COLOR = 1;
    local $Minilla::DEBUG = 0;
    my %fields = (
        event => 'build',
        count => 2,
        message => "first\nsecond\r\n\"quoted\"\\",
        unicode => "\x{65e5}\x{672c}\x{8a9e}\x{1f600}",
        missing => undef,
        details => { files => [ 'lib/Example.pm', 't/example.t' ] },
    );
    my ($stdout, $stderr) = output_from(sub { slog(\%fields) });
    is($stderr, '', 'structured logs do not write to standard error');
    is_deeply(decode_json($stdout), \%fields, 'structured logs preserve field values');
    is(scalar(() = $stdout =~ /\n/g), 1, 'structured logs contain one physical line');
    like($stdout, qr/\n\z/, 'structured logs end with a newline');
    unlike($stdout, qr/[^\x00-\x7f]/, 'Unicode is escaped independently of output encoding');
    unlike($stdout, qr/\e/, 'structured logs are not colored');
}

output_is(
    sub { slog({}) },
    "{}\n",
    '',
    'structured logs support an empty object',
);

output_is(
    sub { slog({ event => 'first' }); slog({ event => 'second' }) },
    "{\"event\":\"first\"}\n{\"event\":\"second\"}\n",
    '',
    'successive structured logs produce separate JSON lines',
);

{
    my $error;
    output_is(
        sub { eval { slog({ callback => sub {} }) }; $error = $@ },
        '',
        '',
        'unencodable structured log values produce no output',
    );
    ok($error, 'JSON encoding errors propagate to the caller');
}

done_testing;
