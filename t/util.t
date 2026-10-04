use strict;
use warnings;
use utf8;

if (@ARGV && $ARGV[0] eq '--editor-helper') {
    shift @ARGV;
    my $output = shift @ARGV;
    open my $fh, '>', $output or die "Cannot open '$output': $!";
    print {$fh} join "\n", @ARGV;
    close $fh or die "Cannot close '$output': $!";
    exit;
}

use Test::More;
use File::Temp qw(tempfile);
use Minilla::Util qw(edit_file slurp);

my ($fh, $output) = tempfile();
close $fh or die "Cannot close '$output': $!";

local $ENV{EDITOR} = qq{"$^X" "$0" --editor-helper "$output" --wait};
edit_file('Changes');

is slurp($output), "--wait\nChanges",
    'EDITOR may contain command-line arguments';

done_testing;
