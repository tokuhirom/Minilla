package Minilla::License::Unknown;
use strict;
use warnings;
use utf8;

use Moo;

has holder => (
    is => 'rw',
    required => 1,
);

no Moo;

sub name { 'Unknown license' }
sub url  { 'http://example.com' }
sub meta_name  { 'unknown' }
sub meta2_name { 'unknown' }

sub fulltext {
    my ($self) = @_;
    return "Minilla cannot detect license terms.";
}

1;

