package Minya::CLI;
use strict;
use warnings;
use utf8;
use Minya;
use Getopt::Long;
use Minya::Errors;
use Try::Tiny;
use Term::ANSIColor qw(colored);
use File::Basename;
use Cwd ();
use File::Temp;
use File::pushd;
use Path::Tiny;
use JSON::PP;
use Data::Dumper; # serializer
use Module::CPANfile;
use Text::MicroTemplate;
use Minya::Util;
use Module::Runtime qw(require_module);
use ExtUtils::MakeMaker qw(prompt);
use Minya::Metadata;
use TOML qw(from_toml to_toml);

use Minya::Config;
use Minya::WorkDir;

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

has debug => (
    is => 'rw',
);

has auto_install => (
    is => 'rw',
    default => sub { 1 },
);

has [qw(base_dir config prereq_specs work_dir_base work_dir)] => (
    is => 'lazy',
);

no Moo;

sub new {
    my $class = shift;

    bless {
        auto_install => 1,
    }, $class;
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
    );
 
    push @commands, @ARGV;
 
    my $cmd = shift @commands || 'help';
 
    ## no critic
    if (eval sprintf("require Minya::CLI::%s; 1;", ucfirst($cmd))) {
        try {
            my $call = sprintf("Minya::CLI::%s::run", ucfirst($cmd));
            $self->$call(@commands);

            unless ($self->debug) {
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

sub verify_develop_requrires {
    my $self = shift;
    $self->verify_dependencies([qw(develop)], 'requires');
}

sub verify_dependencies {
    my ($self, $phases, $type) = @_;

    if (eval q{require CPAN::Meta::Check; 1;}) { ## no critic
        my @err = CPAN::Meta::Check::verify_dependencies(CPAN::Meta::Prereqs->new($self->prereq_specs), $phases, $type);
        for (@err) {
            if (/Module '([^']+)' is not installed/ && $self->auto_install) {
                my $module = $1;
                $self->print("Installing $module\n");
                $self->cmd('cpanm', $module)
            } else {
                $self->print("Warning: $_\n", ERROR);
            }
        }
    }
}

sub build_dist {
    my ($self, $test) = @_;

    $self->verify_dependencies([qw(runtime)], $_) for qw(requires recommends);
    if ($test) {
        $self->verify_dependencies([qw(test)], $_) for qw(requires recommends);
    }

    my $work_dir = Minya::WorkDir->new(dir => $self->work_dir);
    $work_dir->setup($self);
    return $work_dir->build_tar_ball($self, $test);
}

sub generate_meta {
    my ($self, $release_status) = @_;

    my $dat = {
        "meta-spec" => {
            "version" => "2",
            "url"     => "http://search.cpan.org/perldoc?CPAN::Meta::Spec"
        },
        license => $self->config->license_meta2,
        abstract => $self->config->abstract,
        author => [$self->config->author],
        dynamic_config => 0,
        version => $self->config->version,
        name => $self->config->name,
        prereqs => $self->prereq_specs,
        generated_by => "Minya/$Minya::VERSION",
        release_status => $release_status || 'stable',
    };

    # TODO: provides

    my $meta = CPAN::Meta->new($dat);
    return $meta;
}

sub gather_files {
    my ($self) = @_;
    my $root = $self->base_dir;
    my $guard = pushd($root);
    my @files = map { path($_)->relative($root) } split /\n/, `git ls-files`;
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

sub _build_base_dir {
    my $self = shift;
    my $toml = $self->find_file('minya.toml')
        or $self->error("There is no minya.toml");
    return path($toml)->dirname();
}

sub _build_config {
    my $self = shift;
    Minya::Config->load($self, path($self->base_dir, 'minya.toml'));
}

sub _build_prereq_specs {
    my $self = shift;

    my $cpanfile = Module::CPANfile->load(path($self->base_dir, 'cpanfile'));
    return $cpanfile->prereq_specs;
}

sub _build_work_dir_base {
    my $self = shift;
    my $dirname = $^O eq 'MSWin32' ? '_build' : '.build';
    path($self->base_dir(), $dirname);
}

sub _build_work_dir {
    my $self = shift;
    $self->work_dir_base->child(randstr(8));
}

1;

