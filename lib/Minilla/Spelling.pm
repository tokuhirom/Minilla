package Minilla::Spelling;
use strict;
use warnings;
use utf8;
use File::Find::Rule;
use IPC::Open3;
use Symbol qw(gensym);
use ExtUtils::MakeMaker qw(prompt);

use Moo;

has c => (
    is => 'ro',
    required => 1,
);

no Moo;

sub has_aspell {
    my ($self) = @_;

    my $spell_cmd;
    foreach my $path (split(/:/, $ENV{PATH})) {
        # I want to support aspell only.
        -x "$path/aspell" and do {
            return `aspell dump dicts` =~ /en/;
        };
    }
    return 0;
}

sub check {
    my ($self) = @_;

    # double check.
    unless (eval q{require Pod::Spell; 1;}) {
        $self->c->error("Pod::Spell is not installed!\n");
    }

    local $ENV{LANG} = 'C';
    my $miss;
    for my $file (
        File::Find::Rule->file()->name('*.pm')->in('lib'),
        File::Find::Rule->file()->name('*')->in('script'),
    ) {
        open my $ifh, '<', $file
            or do {
            $self->c->warnf("[Spelling] $file: $!");
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
            $self->c->infof("[Spelling] $file\n");
            print $spell_out;
        }
    }

    return $miss;
}

1;

