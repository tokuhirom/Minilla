package Minya::Plugin::Test::Pod;
use strict;
use warnings;
use utf8;

use Path::Tiny;

sub init {
    my ($self, $c) = @_;

    $c->register_prereqs(
        develop => requires => 'Test::Pod' => 1.41,
    );

    $c->add_trigger('after_setup_workdir' => sub {
         path('xt/pod.t')->spew(<<'...');
use strict;
use Test::More;
eval "use Test::Pod 1.41";
plan skip_all => "Test::Pod 1.41 required for testing POD" if $@;
all_pod_files_ok();
...
    });
}

1;

