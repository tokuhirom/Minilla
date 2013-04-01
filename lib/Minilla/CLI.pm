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
    my $version;
    my $p = Getopt::Long::Parser->new(
        config => [ "no_ignore_case", "pass_through" ],
    );
    $p->getoptions(
        "h|help"         => sub { unshift @commands, 'help' },
        "color!"         => \$Minilla::Logger::COLOR,
        "debug!"         => \$Minilla::DEBUG,
        "auto-install!"  => \$Minilla::AUTO_INSTALL,
        'version!'       => \$version,
    );

    if ($version) {
        print "Minilla: $Minilla::VERSION\n";
        exit 0;
    }
 
    push @commands, @ARGV;
 
    my $cmd = shift @commands || 'help';
    my $klass = sprintf("Minilla::CLI::%s", ucfirst($cmd));
 
    ## no critic
    if (eval sprintf("require %s; 1;", $klass)) {
        try {
            $klass->run(@commands);
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

1;

