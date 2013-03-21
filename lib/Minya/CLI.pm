package Minya::CLI;
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

use Minya;
use Minya::Errors;
use Minya::Config;

use Minya::CLI::New;
use Minya::CLI::Help;
use Minya::CLI::Dist;
use Minya::CLI::Test;
use Minya::CLI::Release;
use Minya::CLI::Install;

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

has [qw(base_dir config)] => (
    is => 'lazy',
);

no Moo;

sub _build_base_dir {
    my $self = shift;
    my $toml = $self->find_file('minya.toml')
        or $self->error(sprintf("There is no minya.toml(%s)", Cwd::getcwd()));
    return File::Spec->rel2abs(path($toml)->dirname());
}

sub _build_config {
    my $self = shift;
    Minya::Config->load($self, path($self->base_dir, 'minya.toml'));
}

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
    if (eval sprintf("require Minya::CLI::%s; 1;", ucfirst($cmd))) {
        try {
            my $call = sprintf("Minya::CLI::%s::run", ucfirst($cmd));
            $self->$call(@commands);

            if (!$self->debug && $self->{work_dir}) {
                $self->work_dir_base->remove_tree({safe => 0});
            }
        } catch {
            /Minya::Error::CommandExit/ and return;
            $self->print($_, ERROR);
            exit 1;
        }
    } else {
        $self->error("Could not find command '$cmd'\n");
    }
}

sub cmd {
    my $self = shift;
    $self->print("@_\n", INFO);
    system(@_) == 0
        or $self->error("Giving up.\n");
}

sub find_file {
    my ($self, $file) = @_;

    my $dir = Cwd::getcwd();
    my %seen;
    while ( -d $dir ) {
        return undef if $seen{$dir}++;    # guard from deep recursion
        if ( -f "$dir/$file" ) {
            return "$dir/$file";
        }
        $dir = dirname($dir);
    }

    my $cwd = Cwd::getcwd;
    $self->error("$file not found in $cwd.");
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
    $self->print(sprintf($temp, @args), $type);
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
    Minya::Error::CommandExit->throw;
}

sub parse_options {
    my ( $self, $args, @spec ) = @_;
    Getopt::Long::GetOptionsFromArray( $args, @spec );
}

1;

