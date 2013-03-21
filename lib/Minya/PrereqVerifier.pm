package Minya::PrereqVerifier;
use strict;
use warnings;
use utf8;
use File::Spec;
use Module::CPANfile;
use Minya::Logger;

use Moo;

has base_dir => (
    is => 'ro',
    required => 1,
);

has auto_install => (
    is => 'ro',
    required => 1,
);

has c => (
    is => 'ro',
    required => 1,
);

no Moo;

sub verify {
    my ($self, $phases, $type) = @_;

    my $cpanfile = Module::CPANfile->load(File::Spec->catfile($self->base_dir, 'cpanfile'));
    if (eval q{require CPAN::Meta::Check; 1;}) { ## no critic
        my @err = CPAN::Meta::Check::verify_dependencies($cpanfile->prereqs, $phases, $type);
        for (@err) {
            if (/Module '([^']+)' is not installed/ && $self->auto_install) {
                my $module = $1;
                $self->c->print("Installing $module\n");
                $self->cmd('cpanm', $module)
            } else {
                $self->c->print("Warning: $_\n", ERROR);
            }
        }
    }
}

1;

