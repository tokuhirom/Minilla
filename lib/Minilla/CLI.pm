package Minilla::CLI;
use strict;
use warnings;
use utf8;
use Getopt::Long;
use Try::Tiny;

use Minilla;
use Minilla::Errors;
use Minilla::Project;
use Minilla::Util qw(find_dir);
use Minilla::Logger;

use Minilla::CLI::New;
use Minilla::CLI::Help;
use Minilla::CLI::Dist;
use Minilla::CLI::Test;
use Minilla::CLI::Release;
use Minilla::CLI::Install;

use Moo;

no Moo;

sub run {
    my ($self, @args) = @_;
 
    local $Minilla::AUTO_INSTALL = 1;
    local $Minilla::Logger::COLOR = -t STDOUT ? 1 : 0;
    local @ARGV = @args;
    my @commands;
    my $p = Getopt::Long::Parser->new(
        config => [ "no_ignore_case", "pass_through" ],
    );
    $p->getoptions(
        "h|help"         => sub { unshift @commands, 'help' },
        "color!"         => \$Minilla::Logger::COLOR,
        "debug!"         => \$Minilla::DEBUG,
        "auto-install!"  => \$Minilla::AUTO_INSTALL,
    );
 
    push @commands, @ARGV;
 
    my $cmd = shift @commands || 'help';
 
    ## no critic
    if (eval sprintf("require Minilla::CLI::%s; 1;", ucfirst($cmd))) {
        try {
            my $call = sprintf("Minilla::CLI::%s::run", ucfirst($cmd));
            $self->$call(@commands);
        } catch {
            /Minilla::Error::CommandExit/ and return;
            errorf("%s\n", $_);
            exit 1;
        }
    } else {
        warnf("Could not find command '%s'\n", $cmd);
        if ($@ !~ /^Can't locate Minilla/) {
            errorf("$@\n");
        }
        exit 2;
    }
}

sub parse_options {
    my ( $self, $args, @spec ) = @_;
    Getopt::Long::GetOptionsFromArray( $args, @spec );
}

1;

