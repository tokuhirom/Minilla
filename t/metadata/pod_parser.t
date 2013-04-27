use strict;
use warnings;
use utf8;
use Test::More;

use Minilla::Metadata::PodParser;

my $parser = Minilla::Metadata::PodParser->new();
$parser->parse_file('lib/Minilla.pm');
is($parser->abstract, 'CPAN module authoring tool');

done_testing;

