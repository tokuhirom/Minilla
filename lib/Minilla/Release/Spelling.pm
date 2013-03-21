package Minilla::Release::Spelling;
use strict;
use warnings;
use utf8;
use File::Find::Rule;
use IPC::Open3;
use Symbol qw(gensym);
use ExtUtils::MakeMaker qw(prompt);

sub run {
    my ($self, $c) = @_;

    unless (eval "use Pod::Spell; 1;") {
        $c->infof("There is no Pod::Spell. Skipping spelling check\n");
        # There is no Pod::Spell
        return;
    }

    local $ENV{LANG} = 'C';
    my $spell_cmd;
    foreach my $path (split(/:/, $ENV{PATH})) {
        # I want to support aspell only.
        -x "$path/aspell" and $spell_cmd="aspell list -l en", last;
    }
    unless ($spell_cmd) {
        $c->infof("There is no aspell. Skipping spelling check\n");
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

    my $miss;
    for my $file (
        File::Find::Rule->file()->name('*.pm')->in('lib'),
        File::Find::Rule->file()->name('*')->in('script'),
    ) {
        open my $ifh, '<', $file
            or do {
            $c->warnf("[Spelling] $file: $!");
            next;
        };
        open my $ofh, '>', \my $pod_out;
        Pod::Spell->new->parse_from_filehandle($ifh, $ofh);
        next unless $pod_out;

        my ($wtr, $rdr, $err);
        my $pid = open3($wtr, $rdr, $err, 'aspell', 'list', '-l', 'en');
        print {$wtr} $pod_out;
        close $wtr;
        my $spell_out;
        $spell_out .= $_ while <$rdr>;
        waitpid($pid, 0);

        if ($spell_out) {
            $miss++;
            $c->infof("[Spelling] $file\n");
            print $spell_out;
        }
    }

    if ($miss) {
        print "\n";

        if (prompt("There is some spelling miss. Continue?", 'n') !~ /y/i) {
            $c->error("Giving up!\n");
        }
    }
}

1;
__END__

=head1 NAME

Minilla::Release::Spelling - Spellling check step

=head1 DESCRIPTION

This step checks spelling by `aspell` command.

This step only run if C<< ~/.aspell.en.pws >> exists.

