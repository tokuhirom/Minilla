package Minya::Util;
use strict;
use warnings;
use utf8;
use autodie;

use parent qw(Exporter);

our @EXPORT = qw(randstr slurp);

sub randstr {
    my $len = shift;
    my @chars = ("a".."z","A".."Z",0..9);
    my $ret = '';
    join('', map { $chars[int(rand(scalar(@chars)))] } 1..$len);
}

sub slurp {
    my $fname = shift;
    open my $fh, '<', $fname;
    do { local $/; <$fh> }
}

1;

