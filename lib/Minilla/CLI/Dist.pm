package Minilla::CLI::Dist;
use strict;
use warnings;
use utf8;
use Minilla::WorkDir;
use Path::Tiny;

sub run {
    my ($self, @args) = @_;

    my $test = 1;
    $self->parse_options(
        \@args,
        'test!' => \$test,
    );

    my $work_dir = Minilla::WorkDir->instance($self);
    if ($test) {
        $work_dir->dist_test();
    }
    my $tar = $work_dir->dist();
    my $dst = path($self->base_dir, path($tar)->basename);
    path($tar)->copy($dst);
}

1;
__END__

=head1 NAME

Minilla::CLI::Dist - Make tar ball distribution

=head1 SYNOPSIS

    % minil dist

=head1 DESCRIPTION

This subcommand makes distribution tar ball.

