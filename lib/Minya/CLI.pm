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

use Class::Accessor::Lite 0.05 (
    rw => [qw(minya_json cpanfile base_dir work_dir work_dir_base debug)],
);

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
        "debug!"    => \$self->{debug},
        "verbose!"  => \$self->{verbose},
    );
 
    push @commands, @ARGV;
 
    my $cmd = shift @commands || 'help';
    my $call = $self->can("cmd_$cmd");
 
    if ($call) {
        try {
            $self->minya_json($self->find_file('minya.json'));
            $self->cpanfile(Module::CPANfile->load($self->find_file('cpanfile')));
            $self->base_dir(File::Basename::dirname($self->minya_json));
            $self->work_dir_base($self->_build_work_dir_base);
            $self->verify_dependencies([qw(develop)], 'requires');
            for (grep { -d $_ } $self->work_dir_base()->children) {
                $self->print("Removing $_\n", INFO);
                $_->remove_tree({safe => 0});
            }
            $self->work_dir($self->work_dir_base->child(randstr(8)));

            {
                my $guard = pushd($self->base_dir);
                $self->$call(@commands);
            }
            unless ($self->debug) {
                $self->work_dir->remove_tree({safe => 0});
            }
        } catch {
            /Minya::Error::CommandExit/ and return;
            die $_;
        }
    } else {
        $self->error("Could not find command '$cmd'\n");
    }
}

sub verify_dependencies {
    my ($self, $phases, $type) = @_;
    require CPAN::Meta::Check;
    my @err = CPAN::Meta::Check::verify_dependencies($self->cpanfile->prereqs, $phases, $type);
    $self->print("Warning: $_\n", ERROR) for @err;
}

sub _build_work_dir_base {
    my $self = shift;
    my $dirname = $^O eq 'MSWin32' ? '_build' : '.build';
    path($self->base_dir(), $dirname);
}

sub randstr {
    my $len = shift;
    my @chars = ("a".."z","A".."Z",0..9);
    my $ret = '';
    join('', map { $chars[int(rand(scalar(@chars)))] } 1..$len);
}

sub read_config {
    my ($self) = @_;
    my $path = $self->minya_json;
    my $conf = JSON::PP::decode_json(path($path)->slurp_utf8);

    # validation
    $conf->{'name'} || $self->error("Missing name in minya.json\n");
    $conf->{'version'} || $self->error("Missing version in minya.json\n");
    $conf->{'license'} ||= 'unknown';

    return $conf;
}

sub cmd_test {
    my ($self, @args) = @_;

    $self->parse_options(
        \@args,
    );

    $self->verify_dependencies([qw(test runtime)], $_) for qw(requires recommends);
    $self->cmd($self->read_config->{test_command} || 'prove -l -r t xt');
}

sub render {
    my ($self, $tmpl, @args) = @_;
    my $mt = Text::MicroTemplate->new(
        escape_func => sub { $_[0] },
        package_name => __PACKAGE__,
        template => $tmpl,
    );
    my $src = $mt->code();
    my $code = eval $src; ## no critic.
    $self->error("Cannot compile template: $@\n") if $@;
    $code->(@args);
}

# Make new dist
sub cmd_new {
    my ($self, @args) = @_;
    ...
}

# release to CPAN by CPAN::Uploader
sub cmd_release {
    my ($self, @args) = @_;
    ...
}

# Can I make dist directly without M::B?
sub cmd_dist {
    my ($self, @args) = @_;

    my $notest;
    $self->parse_options(
        \@args,
        'notest!' => \$notest,
    );

    my $guard = $self->setup_mb();

    $self->cmd($^X, 'Build.PL');
    unless ($notest) {
        local $ENV{RELEASE_TESTING} = 1;
        $self->cmd($^X, 'Build', 'disttest');
    }
    $self->cmd($^X, 'Build', 'dist');
}

# TODO: install by EU::Install?
sub cmd_install {
    my $self = shift;

    my $guard = $self->setup_mb();
    $self->cmd($^X, 'Build.PL');
    $self->cmd($^X, 'Build', 'install');
}

sub setup_workdir {
    my $self = shift;

    unless (-e 'MANIFEST') {
        $self->error("There is no MANIFEST file\n");
    }
    my $manifest = ExtUtils::Manifest::maniread();

    # clean up
    ExtUtils::Manifest::manicopy($manifest, $self->work_dir);

    return pushd($self->work_dir);
}

sub setup_mb {
    my ($self) = @_;

    my $config = $self->read_config();

    my $guard = $self->setup_workdir();

    # TODO: Equivalent to M::I::GithubMeta is required?

    # Should I use EU::MM instead of M::B?
    local $Data::Dumper::Terse = 1;
    path('Build.PL')->spew($self->render(<<'...', $config, $self->cpanfile->prereq_specs));
? my $config = shift;
? my $prereq = shift;
? use Data::Dumper;
use strict;
use Module::Build;
use <?= $prereq->{runtime}->{requires}->{perl} || '5.008001' ?>;

my $builder = Module::Build->new(
    dynamic_config       => 0,

    no_index    => { 'directory' => [ 'inc' ] },
    name        => '<?= $config->{name} ?>',
    dist_name   => '<?= $config->{name} ?>',
    dist_version => '<?= $config->{version} ?>',
    license     => '<?= $config->{license} || "unknown" ?>',
    script_files => <?= Dumper($config->{script_files}) ?>,
    # TODO: more deps.
    configure_requires => <?= Dumper(+{ 'Module::Build' => 0.40, %{$prereq->{configure}->{requires} || {} } }) ?>,
    requires => <?= Dumper(+{ %{$prereq->{runtime}->{requires} || {} } }) ?>,
    build_requires => <?= Dumper(+{ %{$prereq->{build}->{requires} || {} } }) ?>,

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

