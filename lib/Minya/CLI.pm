package Minya::CLI;
use strict;
use warnings;
use utf8;
use Getopt::Long;
use Minya::Errors;
# use Minya::Util;
use Try::Tiny;
use Term::ANSIColor qw(colored);
use File::Basename;
use Cwd ();
use File::Temp;
use File::pushd;
use Path::Tiny;
use ExtUtils::Manifest;
use JSON::PP;
use Data::Dumper; # serializer
use Module::CPANfile;
use Text::MicroTemplate;

use constant { SUCCESS => 0, INFO => 1, WARN => 2, ERROR => 3 };

our $Colors = {
    SUCCESS, => 'green',
    WARN,    => 'yellow',
    INFO,    => 'cyan',
    ERROR,   => 'red',
};

sub new {
    my $class = shift;

    bless {
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
        "v|version" => sub { unshift @commands, 'version' },
        "color!"    => \$self->{color},
        "verbose!"  => \$self->{verbose},
    );
 
    push @commands, @ARGV;
 
    my $cmd = shift @commands || 'help';
    my $call = $self->can("cmd_$cmd");
 
    if ($call) {
        try {
            $self->$call(@commands);
        } catch {
            /Minya::Error::CommandExit/ and return;
            die $_;
        }
    } else {
        $self->error("Could not find command '$cmd'\n");
    }
}

sub read_config {
    my ($self) = @_;
    my $path = $self->find_file('minya.json');
    my $conf = JSON::PP::decode_json(path($path)->slurp_utf8);

    # validation
    $conf->{'name'} || $self->error("Missing name in minya.ini\n");
    $conf->{'license'} ||= 'unknown';

    return $conf;
}

sub cmd_test {
    my ($self, @args) = @_;

    $self->parse_options(
        \@args,
    );

    $self->cmd('prove', '-l', '-r', 't', 'xt');
}

sub render {
    my ($self, $tmpl, @args) = @_;
    my $mt = Text::MicroTemplate->new(
        escape_func => sub { $_[0] },
        package_name => __PACKAGE__,
        template => $tmpl,
    );
    my $src = $mt->code();
    my $code = eval $src;
    $self->error("Cannot compile template: $@\n") if $@;
    $code->(@args);
}

sub cmd_dist {
    my ($self, @args) = @_;

    my $notest;
    $self->parse_options(
        \@args,
        'notest!' => \$notest,
    );

    $self->error(sprintf("There is no cpanfile: %s\n", Cwd::getcwd())) unless -f 'cpanfile';
    my $guard = $self->setup_mb();
    
    $self->cmd($^X, 'Build.PL');
    unless ($notest) {
        $self->cmd($^X, 'Build', 'disttest');
    }
    $self->cmd($^X, 'Build', 'dist');
}

sub cmd_install {
    my $self = shift;
    my $guard = pushd($self->base_dir());
    {
        my $guard2 = $self->setup_mb();
        $self->cmd($^X, 'Build.PL');
        $self->cmd($^X, 'Build', 'install');
    }
    path($guard, '_minya')->remove_tree({safe => 0});
}

sub base_dir {
    my $self = shift;
    my $cpanfile = $self->find_file('cpanfile');
    return File::Basename::dirname($cpanfile);
}

sub setup_mb {
    my ($self) = @_;

    my $cpanfile = Module::CPANfile->load($self->find_file('cpanfile'));

    my $config = $self->read_config();

    unless (-e 'MANIFEST') {
        $self->error("There is no MANIFEST file\n");
    }
    my $manifest = ExtUtils::Manifest::maniread();

    # clean up
    $self->print("Building _minya\n", INFO);
    path('_minya')->remove_tree({safe => 0});
    path('_minya')->mkpath();

    ExtUtils::Manifest::manicopy($manifest, '_minya');

    my $guard = pushd('_minya');

    local $Data::Dumper::Terse = 1;
    path('Build.PL')->spew($self->render(<<'...', $config, $cpanfile->prereq_specs));
? my $config = shift;
? my $prereq = shift;
? use Data::Dumper;
use strict;
use Module::Build;

my $builder = Module::Build->new(
    dynamic_config       => 0,

    no_index    => { 'directory' => [ 'inc' ] },
    name        => '<?= $config->{name} ?>',
    license     => '<?= $config->{license} || "unknown" ?>',
    script_files => <?= Dumper($config->{script_files}) ?>,
    # TODO: more deps.
    configure_requires => <?= Dumper(+{ 'Module::Build' => 0.40, %{$prereq->{configure}->{requires} || {} } }) ?>,
    requires => <?= Dumper(+{ %{$prereq->{runtime}->{requires} || {} } }) ?>,
    build_requires => <?= Dumper(+{ %{$prereq->{build}->{requires} || {} } }) ?>,
    module_name => 'Minya',

    test_files => 't/',
    recursive_test_files => 1,

    create_readme  => 1,
    create_license => 1,
);
$builder->create_build_script();
...
    return $guard;
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

sub cmd_help {
    my $self = shift;
    my $module = $_[0] ? ( "Minya::Doc::" . ucfirst $_[0] ) : "Minya";
    system "perldoc", $module;
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

