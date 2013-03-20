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
use Archive::Tar;
use ExtUtils::MakeMaker qw(prompt);
use Minya::Metadata;
use TOML qw(from_toml to_toml);

use Minya::Config;

use Minya::CLI::New;
use Minya::CLI::Help;
use Minya::CLI::Test;

use Class::Accessor::Lite 0.05 (
    rw => [qw(work_dir work_dir_base debug)],
);

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

has auto_install => (
    is => 'rw',
    default => sub { 1 },
);

has [qw(base_dir config prereq_specs)] => (
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
    my $call = $self->can("cmd_$cmd");
 
    if ($call) {
        try {
            if ($cmd eq 'new' || $cmd eq 'setup' || $cmd eq 'help') {
                $self->$call(@commands);
            } else {
                my $config_file = $self->find_file('minya.toml')
                    or $self->error("There is no minya.toml\n");

                $self->work_dir_base($self->_build_work_dir_base)->mkpath;
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

sub _build_work_dir_base {
    my $self = shift;
    my $dirname = $^O eq 'MSWin32' ? '_build' : '.build';
    path($self->base_dir(), $dirname);
}

sub cmd_test {
    my ($self, @args) = @_;
    Minya::CLI::Test->run($self, @args);
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
    if (my $current = $self->prereq_specs->{$phase}->{$type}->{$module}) {
        if (version->parse($current) < version->parse($version)) {
            $self->prereq_specs->{$phase}->{$type}->{$module} = $version;
        }
    } else {
        $self->prereq_specs->{$phase}->{$type}->{$module} = $version;
    }
}

# Make new dist
sub cmd_new {
    my ($self, @args) = @_;
    $self->Minya::CLI::New::run(@args);
}

# release to CPAN by CPAN::Uploader
sub cmd_release {
    my ($self, @args) = @_;

    require CPAN::Uploader;

    my $test = 1;
    $self->parse_options(
        \@args,
        'test!' => \$test,
    );

    # perl-revision command is included in Perl::Version.
    $self->cmd('perl-reversion', '-bump');

    my $version = Minya::Metadata->new(source => $self->config->{main_module})->version;

    until (path('Changes')->slurp =~ /^$version/) {
        if (prompt("There is no $version, do you want to edit changes file?", 'y') =~ /y/i) {
            edit_file('Changes');
        } else {
            $self->error("Giving up!");
        }
    }

    my $tar = $self->build_dist($test);

    $self->infof("Upload to CPAN\n");
    my $config = CPAN::Uploader->read_config_file();
    my $uploader = CPAN::Uploader->new(+{
        tar => $tar,
        %$config
    });
    $uploader->upload_file($tar);

    # TODO commit
    # TODO tag
    # TODO push tags
}

# Can I make dist directly without M::B?
sub cmd_dist {
    my ($self, @args) = @_;

    my $test = 1;
    $self->parse_options(
        \@args,
        'test!' => \$test,
    );

    $self->build_dist($test);
}

sub build_dist {
    my ($self, $test) = @_;

    $self->verify_dependencies([qw(runtime)], $_) for qw(requires recommends);
    if ($test) {
        $self->verify_dependencies([qw(test)], $_) for qw(requires recommends);
    }

    my $work_dir = $self->setup_workdir();

    $self->infof("Generating Build.PL\n");
    path('Build.PL')->spew($self->generate_build_pl());

    # Generate meta file
    {
        # TODO: provides
        my $meta = $self->generate_meta();
        $meta->save('META.yml', {
            version => 1.4,
        });
        $meta->save('META.json', {
            version => 2.0,
        });
    }

    my @files = $self->gather_files();
    push @files, qw(Build.PL LICENSE META.json META.yml);

    $self->infof("Writing MANIFEST file\n");
    {
        path('MANIFEST')->spew(join("\n", @files));
    }

    if ($test) {
        local $ENV{RELEASE_TESTING} = 1;
        $self->cmd('prove', '-r', '-l', 't', (-d 'xt' ? 'xt' : ()));
    }

    # Create tar ball
    my $tarball = $self->config->{name} . '-' . $self->config->{version} . '.tar.gz';

    path($self->base_dir, $tarball)->remove;

    my $tar = Archive::Tar->new;
    $tar->add_data(path($self->config->{name} . '-' . $self->config->{version}, $_), path($_)->slurp) for @files;
    $tar->write(path($self->base_dir, $tarball), COMPRESS_GZIP);
    $self->infof("Wrote %s\n", $tarball);

    return $tarball;
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
    };

    $dat->{abstract} = $self->config->{abstract};
    $dat->{author} = [$self->config->{author}];
    $dat->{dynamic_config} = 0;
    $dat->{version} = $self->config->{version};
    $dat->{name} = $self->config->{name};
    $dat->{prereqs} = $self->prereq_specs;
    $dat->{generated_by} = "Minya/$Minya::VERSION";
    $dat->{release_status} = $release_status || 'stable';

    my $meta = CPAN::Meta->new($dat);
    return $meta;
}

sub cmd_install {
    my $self = shift;

    my $tar = $self->build_dist();
    $self->cmd('cpanm', $tar);
    path($tar)->remove unless $self->debug;
}

sub setup_workdir {
    my $self = shift;

    $self->infof("Creating working directory: %s\n", $self->work_dir);

    my @files = $self->gather_files();

    # copying
    path($self->work_dir)->mkpath;
    for my $src (@files) {
        next if -d $src;
        my $dst = path($self->work_dir, path($src)->relative($self->base_dir));
        path($dst->dirname)->mkpath;
        path($src)->copy($dst);
    }

    my $guard = pushd($self->work_dir());
    path('xt')->mkpath;

    $self->write_release_tests();

    return $guard;
}

sub write_release_tests {
    my $self = shift;

    path('xt/minimum_version.t')->spew(<<'...');
use Test::More;
eval "use Test::MinimumVersion 0.101080";
plan skip_all => "Test::MinimumVersion required for testing perl minimum version" if $@;
all_minimum_version_from_metayml_ok();
...

    path('xt/cpan_meta.t')->spew(<<'...');
use Test::More;
eval "use Test::CPAN::Meta";
plan skip_all => "Test::CPAN::Meta required for testing META.yml" if $@;
plan skip_all => "There is no META.yml" unless -f "META.yml";
meta_yaml_ok();
...

    path('xt/pod.t')->spew(<<'...');
use strict;
use Test::More;
eval "use Test::Pod 1.41";
plan skip_all => "Test::Pod 1.41 required for testing POD" if $@;
all_pod_files_ok();
...
}

sub gather_files {
    my ($self) = @_;
    my $root = $self->base_dir;
    my $guard = pushd($root);
    my @files = map { path($_)->relative($root) } split /\n/, `git ls-files`;
}

sub generate_build_pl {
    my ($self) = @_;

    my $config = $self->config();

    # TODO: Equivalent to M::I::GithubMeta is required?
    # TODO: ShareDir?

    # Should I use EU::MM instead of M::B?
    local $Data::Dumper::Terse = 1;
    # Set perl_version
#   $self->register_prereqs(runtime => 'requires' => perl => $perl_version);
    return $self->render(<<'...', $config, $self->prereq_specs, $self);
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
    license     => '<?= $self->config->license || "unknown" ?>',
    script_files => <?= Dumper($config->{script_files}) ?>,
    configure_requires => <?= Dumper(+{ 'Module::Build' => 0.40, %{$prereq->{configure}->{requires} || {} } }) ?>,
    requires => <?= Dumper(+{ %{$prereq->{runtime}->{requires} || {} } }) ?>,
    build_requires => <?= Dumper(+{ %{$prereq->{build}->{requires} || {} } }) ?>,
    test_files => 't/',

    recursive_test_files => 1,

    create_readme  => 1,
);
$builder->create_build_script();
...
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
    Minya::CLI::Help->run(@_);
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

1;

