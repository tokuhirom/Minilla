use strict;
use warnings;
use utf8;
use Test::More;
use t::Util;
# use Test::Requires 'Software::License';
use Minilla::Metadata;

isa_ok(Minilla::Metadata->new(source => 'lib/Minilla.pm')->license, 'Minilla::License::Perl_5');
if (eval "require Software::License; 1;") {
    isa_ok(Minilla::Metadata->new(source => 't/data/bsd.dat')->license, 'Software::License::BSD');
} else {
    diag "Software::License is not installed";
}

done_testing;

