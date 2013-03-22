package Minilla::CLI::Spell;
use strict;
use warnings;
use utf8;
use Minilla::Spelling;

sub run {
    my ($self) = @_;

    my $checker = Minilla::Spelling->new(
        c => $self,
    );
    unless ($checker->has_aspell()) {
        $self->error("aspell(1) is not available\n");
    }
    $checker->check();
}

1;
__END__

=head1 NAME

Minilla::CLI::Spell - Spelling check

=head1 SYNOPSIS

    % minil spell

=head1 DESCRIPTION

Run the spelling checker.

