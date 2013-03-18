package Minya::CLI;
use strict;
use warnings;
use utf8;
use Getopt::Long;
use Minya::Errors;
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
use Minya::Util;
use Module::Runtime qw(require_module);
use CPAN::Meta::Check;
use Data::OptList;
use Software::License;
use Class::Trigger qw(
    after_setup_workdir
);

use Class::Accessor::Lite 0.05 (
    rw => [qw(minya_json cpanfile base_dir work_dir work_dir_base debug config auto_install prereq_specs license)],
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
        color => -t STDOUT ? 1 : 0,
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
        "v|version" => sub { unshift @commands, 'version' },
        "color!"    => \$self->{color},
        "debug!"    => \$self->{debug},
        "verbose!"  => \$self->{verbose},
        "auto-install!"  => \$self->{auto_install},
    );
 
    push @commands, @ARGV;
 
    my $cmd = shift @commands || 'help';
    my $call = $self->can("cmd_$cmd");
 
    if ($call) {
        try {
            if ($call eq 'cmd_new' || $call eq 'cmd_help') {
                $self->$call(@commands);
            } else {
                $self->minya_json($self->find_file('minya.json'));
                $self->config($self->load_config());
                $self->cpanfile(Module::CPANfile->load($self->find_file('cpanfile')));
                $self->prereq_specs($self->cpanfile->prereq_specs);
                $self->base_dir(File::Basename::dirname($self->minya_json));
                $self->work_dir_base($self->_build_work_dir_base)->mkpath;
                $self->load_plugins();
                $self->init_license();
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
                    $self->work_dir_base->remove_tree({safe => 0});
                }
            }
        } catch {
            /Minya::Error::CommandExit/ and return;
            die $_;
        }
    } else {
        $self->error("Could not find command '$cmd'\n");
    }
}

sub init_license {
    my $self = shift;

    my $klass = "Software::License::" . $self->config->{license};
    require_module($klass);
    $self->license(
        $klass->new({
            holder => $self->config->{copyright_holder} || $self->config->{author}
        })
    );
}

sub load_plugins {
    my $self = shift;
    for ( @{Data::OptList::mkopt( $self->config->{plugins} || [] )} ) {
        my $pkg = $_->[0];
        my $config = $_->[1];
        my $klass = $pkg =~ s!^\+!! ? $pkg : "Minya::Plugin::$pkg";
        $self->infof( "Loading plugin: %s\n", $klass );
        require_module($klass);
        $klass->init($self, $config);
    }
}

sub verify_dependencies {
    my ($self, $phases, $type) = @_;
    my @err = CPAN::Meta::Check::verify_dependencies($self->cpanfile->prereqs, $phases, $type);
    for (@err) {
        if (/Module '([^']+)' is not installed/ && $self->auto_install) {
            my $module = $1;
            $self->print("Installing $module");
            $self->cmd('cpanm', $module)
        } else {
            $self->print("Warning: $_\n", ERROR);
        }
    }
}

sub _build_work_dir_base {
    my $self = shift;
    my $dirname = $^O eq 'MSWin32' ? '_build' : '.build';
    path($self->base_dir(), $dirname);
}

sub load_config {
    my ($self) = @_;
    my $path = $self->minya_json;
    my $conf = JSON::PP::decode_json(path($path)->slurp_utf8);

    # validation
    $conf->{'name'} || $self->error("Missing name in minya.json\n");
    $conf->{'author'} || $self->error("Missing author in minya.json\n");
    $conf->{'version'} || $self->error("Missing version in minya.json\n");
    $conf->{'license'} || $self->error("Missing license in minya.json\n");

    return $conf;
}

sub cmd_test {
    my ($self, @args) = @_;

    $self->parse_options(
        \@args,
    );

    my $guard = $self->setup_workdir();
    $self->verify_dependencies([qw(test runtime)], $_) for qw(requires recommends);
    $self->cmd($self->config->{test_command} || 'prove -l -r t xt');
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

sub register_prereqs {
    my ($self, $phase, $type, $module, $version) = @_;
    if (my $current = $self->{$phase}->{$type}->{$module}) {
        if (version->parse($current) < version->parse($version)) {
            $self->{$phase}->{$type}->{$module} = $version;
        }
    } else {
        $self->{$phase}->{$type}->{$module} = $version;
    }
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

    # Generate license file
    path('LICENSE')->spew($self->license->fulltext);

    $self->cmd($^X, 'Build.PL');
    $self->cmd($^X, 'Build', 'manifest');
    $self->cmd($^X, 'Build', 'distmeta');
    unless ($notest) {
        local $ENV{RELEASE_TESTING} = 1;
        $self->cmd('prove', '-r', '-l', 't', 'xt');
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

    $self->infof("Creating working directory: %s\n", $self->work_dir);

    my $manifest = ExtUtils::Manifest::maniread();

    # clean up
    {
        local $ExtUtils::Manifest::Quiet = 1;
        ExtUtils::Manifest::manicopy($manifest, $self->work_dir);
    }

    my $guard = pushd($self->work_dir());
    $self->call_trigger('after_setup_workdir');

    return $guard;
}

sub setup_mb {
    my ($self) = @_;

    my $config = $self->config();

    my $guard = $self->setup_workdir();

    # TODO: Equivalent to M::I::GithubMeta is required?
    # TODO: ShareDir?

    # Should I use EU::MM instead of M::B?
    local $Data::Dumper::Terse = 1;
    path('Build.PL')->spew($self->render(<<'...', $config, $self->prereq_specs, $self));
? my $config = shift;
? my $prereq = shift;
? my $self = shift;
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
    license     => '<?= $self->license->meta_yml_name || "unknown" ?>',
    script_files => <?= Dumper($config->{script_files}) ?>,
    # TODO: more deps.
    configure_requires => <?= Dumper(+{ 'Module::Build' => 0.40, %{$prereq->{configure}->{requires} || {} } }) ?>,
    requires => <?= Dumper(+{ %{$prereq->{runtime}->{requires} || {} } }) ?>,
    build_requires => <?= Dumper(+{ %{$prereq->{build}->{requires} || {} } }) ?>,
    test_files => (-d '.git' || $ENV{RELEASE_TESTING}) ? 't/ xt/' : 't/',

    recursive_test_files => 1,

    create_readme  => 1,
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

sub infof {
    my $self = shift;
    $self->printf(@_, INFO);
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

