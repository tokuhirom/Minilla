package Minya::Plugin::Test::Kwalitee;
use strict;
use warnings;
use utf8;
use Path::Tiny;

sub init {
    my ($self, $c) = @_;

    $c->register_prereqs(
        develop => requires => 'Test::Kwalitee' => 1.01,
    );

    $c->add_trigger('after_setup_workdir' => sub {
         path('xt/kwalitee.t')->spew(<<'...');
use strict;
use Test::More;
unless ($ENV{RELEASE_TESTING}) {
    plan skip_all => "This test only run under RELEASE_TESTING";
}
eval { require Test::Kwalitee; Test::Kwalitee->import() };
plan( skip_all => 'Test::Kwalitee not installed; skipping' ) if $@;
...
    });
}

1;

