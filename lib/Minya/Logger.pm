package Minya::Logger;
use strict;
use warnings;
use utf8;
use parent qw(Exporter);

our @EXPORT = qw(SUCCESS INFO WARN ERROR);

use constant { SUCCESS => 0, INFO => 1, WARN => 2, ERROR => 3 };

1;

