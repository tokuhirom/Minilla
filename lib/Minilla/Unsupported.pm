package Minilla::Unsupported;
use strict;
use warnings;
use utf8;

use Moo;

has os => (
    is      => 'ro',
    isa     => sub { ref $_[0] eq 'ARRAY' },
    default => sub { [] },
);

no Moo;

1;
