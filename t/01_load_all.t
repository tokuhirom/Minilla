use strict;
use warnings;
use utf8;
use Test::More;
use File::Find;
 
find {
    wanted => sub {
        return unless /\.pm$/;
        my $class = substr $_, length($File::Find::topdir) + 1;        $class =~ s/\.pm$//;
        $class =~ s!/!::!g;
        use_ok $class;
    },
    no_chdir => 1,
}, 'lib';

done_testing;
