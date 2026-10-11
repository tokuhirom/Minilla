use strict;
use warnings;
use Test::More;
use lib 't/lib';
use Util;

my ($status, $output) = run_with_open_stdin(
    10, $^X, '-e',
    'print STDOUT "x" x 262144; print STDERR "y" x 262144; exit 1;',
);
is $status >> 8, 1, 'preserves the child exit status';
is $output, ('x' x 262144) . ('y' x 262144),
    'large stdout and stderr do not block while the input pipe remains open';

my $error;
eval { run_with_open_stdin(1, $^X, '-e', 'sleep 30;') };
$error = $@;
like $error, qr/did not exit.*within 1 seconds/,
    'a blocked child is terminated at the deadline';

done_testing;
