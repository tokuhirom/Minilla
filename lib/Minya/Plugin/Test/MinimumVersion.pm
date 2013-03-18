package Minya::Plugin::Test::MinimumVersion;
use strict;
use warnings;
use utf8;

use Path::Tiny;

sub init {
    my ($self, $c) = @_;

    $c->register_prereqs(
        develop => requires => 'Test::MinimumVersion' => '0.101080',
    );

    $c->add_trigger('after_setup_workdir' => sub {
         path('xt/minimum_version.t')->spew(<<'...');
use Test::More;
eval "use Test::MinimumVersion 0.101080";
plan skip_all => "Test::MinimumVersion required for testing perl minimum version" if $@;
all_minimum_version_from_metayml_ok();
...
    });
}

1;

