use strict;
use warnings;
use utf8;
use Test::More;
use Test::Requires qw(Test::AllModules);
use Test::AllModules;

BEGIN {
    all_ok(
        search_path => 'Minilla',
        check       => sub {
            my $class = shift;
            my $ret = eval "use $class;1;";
            diag $@ if $@;
            $ret;
        },
    );
}

