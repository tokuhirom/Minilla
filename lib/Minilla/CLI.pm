package Minilla::CLI;
use strict;
use warnings;
use utf8;
use Getopt::Long;
use Try::Tiny;
use Term::ANSIColor qw(colored);
use File::Basename;
use Cwd ();
use File::pushd;
use Path::Tiny;
use Module::CPANfile;

use Minilla;
use Minilla::Errors;
use Minilla::Project;
use Minilla::Util qw(find_dir);

use Minilla::CLI::New;
use Minilla::CLI::Help;
use Minilla::CLI::Dist;
use Minilla::CLI::Test;
use Minilla::CLI::Release;
use Minilla::CLI::Install;

require Win32::Console::ANSI if $^O eq 'MSWin32';

use constant { SUCCESS => 0, INFO => 1, WARN => 2, ERROR => 3 };

our $Colors = {
    SUCCESS, => 'green',
    WARN,    => 'yellow',
    INFO,    => 'cyan',
    ERROR,   => 'red',
};

use Moo;

has color => (
    is => 'rw',
    default => sub {
        -t STDOUT ? 1 : 0
    },
);

has [qw(debug verbose dry_run)] => (
    is => 'rw',
);

has auto_install => (
    is => 'rw',
    default => sub { 1 },
);

no Moo;

sub run {
    my ($self, @args) = @_;
 
    local @ARGV = @args;
    my @commands;
    my $p = Getopt::Long::Parser->new(
        config => [ "no_ignore_case", "pass_through" ],
    );
    $p->getoptions(
        "h|help"    => sub { unshift @commands, 'help' },
        "color!"    => \$self->{color},
        "debug!"    => \$self->{debug},
        "verbose!"  => \$self->{verbose},
        "auto-install!"  => \$self->{auto_install},
        "dry-run!"       => \$self->{dry_run},
    );
 
    push @commands, @ARGV;
 
    my $cmd = shift @commands || 'help';
 
    ## no critic
    if (eval sprintf("require Minilla::CLI::%s; 1;", ucfirst($cmd))) {
        try {
            my $call = sprintf("Minilla::CLI::%s::run", ucfirst($cmd));
            $self->$call(@commands);

            if (!$self->debug && $self->{work_dir}) {
                $self->work_dir_base->remove_tree({safe => 0});
            }
        } catch {
            /Minilla::Error::CommandExit/ and return;
            $self->print($_, ERROR);
            exit 1;
        }
    } else {
        $self->print("Could not find command '$cmd'\n", ERROR);
        if ($@ !~ /^Can't locate Minilla/) {
            $self->print("$@\n", ERROR);
        }
        exit 2;
    }
}

sub cmd {
    my $self = shift;
    $self->print("@_\n", INFO);
    system(@_) == 0
        or $self->error("Giving up.\n");
}

sub infof {
    my $self = shift;
    $self->printf(@_, INFO);
}

sub warnf {
    my $self = shift;
    $self->printf(@_, WARN);
}

sub printf {
    my $self = shift;
    my $type = pop;
    my($temp, @args) = @_;
    $self->print(sprintf($temp, map { defined($_) ? $_ : '-' } @args), $type);
}
 
sub print {
    my($self, $msg, $type) = @_;
    $msg = colored $msg, $Colors->{$type} if defined $type && $self->{color};
    my $fh = $type && $type >= WARN ? *STDERR : *STDOUT;
    print {$fh} $msg;
}

sub error {
    my($self, $msg) = @_;
    $self->print($msg, ERROR);
    Minilla::Error::CommandExit->throw;
}

sub errorf {
    my($self, @msg) = @_;
    $self->printf(@msg, ERROR);
    Minilla::Error::CommandExit->throw;
}

sub parse_options {
    my ( $self, $args, @spec ) = @_;
    Getopt::Long::GetOptionsFromArray( $args, @spec );
}

1;

