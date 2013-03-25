package Minilla::Gitignore;
use strict;
use warnings;
use utf8;

use Moo;

has lines => (
    is => 'rw',
    default => sub { +[ ] },
);

no Moo;

sub load {
    my ($class, $filename) = @_;

    open my $fh, '<', $filename 
        or die "Cannot open $filename: $!";
    my @lines;
    while (defined($_ = <$fh>)) {
        chomp;
        push @lines, $_;
    }

    return $class->new(
        lines => [@lines],
    );
}

sub remove {
    my ($self, $pattern) = @_;
    if (ref $pattern) {
        $self->lines([grep { $_ !~ $pattern } @{$self->lines}]);
    } else {
        $self->lines([grep { $_ ne $pattern } @{$self->lines}]);
    }
}

sub add {
    my ($self, $pattern) = @_;

    unless (grep { $pattern eq $_ } @{$self->lines}) {
        push @{$self->lines}, $pattern;
    }
}

sub as_string {
    my $self = shift;
    return join('', map { "$_\n" } @{$self->lines});
}

sub save {
    my ($self, $filename) = @_;
    open my $fh, '>', $filename
        or die "Cannot open $filename: $!";
    for (@{$self->lines}) {
        print {$fh} $_, "\n";
    }
    close $fh;
}

1;

