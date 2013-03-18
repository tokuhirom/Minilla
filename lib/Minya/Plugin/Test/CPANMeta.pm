package Minya::Plugin::Test::CPANMeta;
use strict;
use warnings;
use utf8;

use Path::Tiny;

sub init {
    my ($self, $c) = @_;

    $c->register_prereqs(
        develop => requires => 'Test::CPAN::Meta' => 0,
    );

    $c->add_trigger('after_setup_workdir' => sub {
         path('xt/cpan_meta.t')->spew(<<'...');
use Test::More;
eval "use Test::CPAN::Meta";
plan skip_all => "Test::CPAN::Meta required for testing META.yml" if $@;
plan skip_all => "There is no META.yml" unless -f "META.yml";
meta_yaml_ok();
...
    });
}

1;

