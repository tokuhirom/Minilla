use strict;
use warnings;
use utf8;
use Test::More;
# use Test::Requires 'Software::License';
use Minilla::Metadata;

is(Minilla::Metadata->new(source => 'lib/Minilla.pm')->license, 'Minilla::License::Perl_5');
is(Minilla::Metadata->new(source => 't/data/bsd.dat')->license, 'bsd');

done_testing;

