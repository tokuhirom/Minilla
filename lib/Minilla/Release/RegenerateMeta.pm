package Minilla::Release::RegenerateMeta;
use strict;
use warnings;
use utf8;
use File::pushd;
use Module::CPANfile;
use Minilla::CPANMeta;

sub run {
    my ($self, $c, $opts) = @_;

    my $guard = pushd($c->base_dir);

    my $cpanfile = Module::CPANfile->load('cpanfile');
    my $meta = Minilla::CPANMeta->new(
        config       => $c->config,
        prereq_specs => $cpanfile->prereq_specs,
        base_dir     => '.',
    )->generate('unstable');
    $meta->save('META.json', {
        version => 2.0,
    });
}

1;

