use strict;
use warnings;
use utf8;
use Test::AllModules;

BEGIN {
    all_ok(
        search_path => 'Minya',
        check       => sub {
            my $class = shift;
            eval "use $class;1;";
        },
    );
}

