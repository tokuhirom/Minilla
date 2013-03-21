package Minya::CLI::Meta;
use strict;
use warnings;
use utf8;
use Path::Tiny;
use Minya::CPANMeta;
use Module::CPANfile;
use Minya::Util qw(find_file);
use File::pushd;
use File::Spec::Functions qw(catfile);

sub run {
    my ($self, @args) = @_;

    $self->parse_options(
        \@args,
    );

    my $guard = pushd($self->base_dir);

    my $cpanfile = Module::CPANfile->load(catfile($self->base_dir, 'cpanfile'));
    my $meta = Minya::CPANMeta->new(
        config       => $self->config,
        prereq_specs => $cpanfile->prereq_specs,
        base_dir     => $self->base_dir,
    )->generate('unstable');
    $meta->save('META.json', {
        version => '2.0'
    });
}

1;

