use strict;
use warnings;
use utf8;
use Test::More;
# use Test::Requires 'Software::License';
use Minilla::Metadata;

isa_ok(Minilla::Metadata->new(source => 'lib/Minilla.pm')->license, 'Minilla::License::Perl_5');
isa_ok(Minilla::Metadata->new(source => 't/data/bsd.dat')->license, 'Software::License::BSD');

done_testing;

