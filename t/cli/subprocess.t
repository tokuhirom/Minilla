use strict;
use warnings;

if (@ARGV && $ARGV[0] eq '--output-helper') {
    binmode STDOUT;
    binmode STDERR;
    print STDOUT 'x' x 262144;
    print STDERR 'y' x 262144;
    exit 1;
}
if (@ARGV && $ARGV[0] eq '--sleep-helper') {
    sleep 30;
    exit;
}

use Test::More;
use lib 't/lib';
use Util;

my ($status, $output) = run_with_open_stdin(
    10, $^X, File::Spec->rel2abs($0), '--output-helper',
);
is $status >> 8, 1, 'preserves the child exit status';
is length($output), 524288, 'captures large output without blocking';
ok $output eq ('x' x 262144) . ('y' x 262144),
    'captures both output streams with the input pipe still open';

my $error;
eval { run_with_open_stdin(1, $^X, File::Spec->rel2abs($0), '--sleep-helper') };
$error = $@;
like $error, qr/did not exit.*within 1 seconds/,
    'a blocked child is terminated at the deadline';

done_testing;
