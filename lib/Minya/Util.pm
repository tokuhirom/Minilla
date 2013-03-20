package Minya::Util;
use strict;
use warnings;
use utf8;
use autodie;

use parent qw(Exporter);

our @EXPORT_OK = qw(find_file module_name2path slurp_utf8 randstr slurp spew edit_file);

sub module_name2path {
    local $_ = shift;
    s!::!/!;
    "lib/$_.pm";
}

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

sub slurp_utf8 {
    my $fname = shift;
    open my $fh, '<:encoding(UTF-8)', $fname;
    do { local $/; <$fh> }
}

sub spew {
    my $fname = shift;
    open my $fh, '>', $fname;
    print {$fh} $_[0];
}

sub edit_file {
    my ($file) = @_;
    my $editor = $ENV{"EDITOR"} || "vi";
    system( $editor, $file );
}

sub find_file {
    my ($file) = @_;

    my $dir = Cwd::getcwd();
    my %seen;
    while ( -d $dir ) {
        return undef if $seen{$dir}++;    # guard from deep recursion
        if ( -f "$dir/$file" ) {
            return "$dir/$file";
        }
        $dir = dirname($dir);
    }

    return undef;
}

1;

