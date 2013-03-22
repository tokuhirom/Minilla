package Minilla::Release::Spelling;
use strict;
use warnings;
use utf8;
use ExtUtils::MakeMaker qw(prompt);

use Minilla::Spelling;

sub run {
    my ($self, $c) = @_;

    unless (eval "use Pod::Spell; 1;") {
        $c->infof("There is no Pod::Spell. Skipping spelling check\n");
        # There is no Pod::Spell
        return;
    }

    if (-f 'xt/01_podspell.t') {
        $c->infof("There is xt/01_podspell.t. Skipping minil's spelling check\n");
        return;
    }

    my $checker = Minilla::Spelling->new(
        c => $c,
    );

    unless ($checker->has_aspell()) {
        $c->infof("aspell(1) is not available. Skipping spelling check\n");
        return;
    }

    unless ($ENV{HOME}) {
        $c->infof("There is no ENV[HOME]. Skipping spelling check\n");
        return;
    }
    my $userdict = File::Spec->catfile($ENV{HOME}, '.aspell.en.pws');
    unless (-f $userdict) {
        $c->infof("There is no $userdict. Skipping spelling check\n");
        return;
    }

    if (my $fail = $checker->check()) {
        print "\n";

        if (prompt("There is some spelling miss. Continue?", 'n') !~ /y/i) {
            $c->error("Giving up!\n");
        }
    }
}

1;
__END__

=head1 NAME

Minilla::Release::Spelling - Spelling check step

=head1 DESCRIPTION

This step checks spelling by `aspell` command.

This step only run if C<< ~/.aspell.en.pws >> exists.

