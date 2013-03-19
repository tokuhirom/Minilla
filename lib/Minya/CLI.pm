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
use CPAN::Meta::Check;
use YAML::Tiny;
use Data::OptList;
use Software::License;
use Path::Iterator::Rule;
use File::HomeDir;
use Archive::Tar;
use ExtUtils::MakeMaker qw(prompt);
use TOML qw(from_toml to_toml);
use Class::Trigger qw(
    after_setup_workdir
);

use Class::Accessor::Lite 0.05 (
    rw => [qw(minya_toml base_dir work_dir work_dir_base debug config auto_install prereq_specs license)],
);

require Win32::Console::ANSI if $^O eq 'MSWin32';

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
            if ($call eq 'cmd_new' || $call eq 'cmd_setup' || $call eq 'cmd_help') {
                $self->$call(@commands);
            } else {
                $self->minya_toml($self->find_file('minya.toml'))
                    or $self->error("There is no minya.toml\n");
                $self->config($self->load_config());
                my $cpanfile = Module::CPANfile->load($self->find_file('cpanfile'));
                $self->prereq_specs($cpanfile->prereq_specs);
                $self->base_dir(File::Basename::dirname($self->minya_toml));
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

    for ( grep /\A[A-Z]/, keys %{$self->config} ) {
        my $pkg = $_;
        my $config = $self->config->{$_};
        my $klass = $pkg =~ s!^\+!! ? $pkg : "Minya::Plugin::$pkg";
        $self->infof( "Loading plugin: %s\n", $klass );
        require_module($klass);
        $klass->init($self, $config);
    }
}

sub verify_dependencies {
    my ($self, $phases, $type) = @_;
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

sub _build_work_dir_base {
    my $self = shift;
    my $dirname = $^O eq 'MSWin32' ? '_build' : '.build';
    path($self->base_dir(), $dirname);
}

sub load_config {
    my ($self) = @_;
    my $path = $self->minya_toml;

    my ($conf, $err) = from_toml(path($path)->slurp_utf8);
    if ($err) {
        $self->error("TOML error in $path: $err");
    }

    # validation
    for (qw(name author version license)) {
        $conf->{$_} || $self->error("Missing $_ in minya.toml\n");
    }
    if ($conf->{version} =~ /\A[0-9]+\.[0-9]+\.[0-9]+\z/) {
        $conf->{version} = 'v' . $conf->{version};
    }

    return $conf;
}

sub cmd_test {
    my ($self, @args) = @_;

    $self->parse_options(
        \@args,
    );

    my $guard = $self->setup_workdir();
    $self->verify_dependencies([qw(test runtime)], $_) for qw(requires recommends);
    $self->cmd($self->config->{test_command} || 'prove -l -r t ' . (-d 'xt' ? 'xt' : ''));
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

# XXX is it works?
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

sub global_config {
    my $self = shift;
    my $path = path(File::HomeDir->my_home, '.minyarc');
    if (-e $path) {
        JSON::PP::decode_json($path->slurp);
    } else {
        +{}
    }
}

# Make new dist
sub cmd_new {
    my ($self, @args) = @_;

    $self->parse_options(
        \@args,
    );
    my $module = shift @args or $self->error("Missing module name\n");

    # $module = "Foo::Bar"
    # $suffix = "Bar"
    # $dist   = "Foo-Bar"
    # $path   = "Foo/Bar.pm"
    my @pkg    = split /::/, $module;
    my $suffix = $pkg[ @pkg - 1 ];
    my $dist   = join "-", @pkg;
    my $path   = join( "/", @pkg ) . ".pm";
    ( my $dir = $dist ) =~ s/^App-//;
    path(path($dist, 'lib', $path)->dirname)->mkpath;
    path($dist, 'lib', $path)->spew(sprintf(<<'...', $module));
package %s;
use strict;
use warnings;

1;
...
    path($dist, '.gitignore')->spew(<<'...');
/.build/
/_build/
...
    path($dist, 'minya.toml')->spew(to_toml(+{
        name => $dist,
        author => $self->global_config->{'user_name'},
        copyright_holder => $self->global_config->{'user_name'},
        version => '0.0.1',
        license => $self->global_config->{'license'} || 'Perl_5',
        "Test::Pod" => {},
        "Test::CPANMeta" => {},
        "Test::MinimumVersion" => {},
    }));
    path($dist, 't')->mkpath;
    path($dist, 't', '00_compile.t')->spew(sprintf(<<'...', $module));
use strict;
use Test::More;

use_ok $_ for qw(
    %s
);

done_testing;
...
    $self->infof("Finished to create $module\n");
}

sub cmd_setup {
    my ($self, @args) = @_;
    my $global_config = $self->global_config();
    $global_config->{user_name} = prompt("User name:", $global_config->{user_name});
    $global_config->{email} = prompt("User E-mail:", $global_config->{email});
    $global_config->{license} = prompt("License:", $global_config->{license} || 'Perl_5');
    path(File::HomeDir->my_home, '.minyarc')->spew(JSON::PP->new->ascii(1)->encode($global_config));
}

# release to CPAN by CPAN::Uploader
sub cmd_release {
    my ($self, @args) = @_;
    ...
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

    $self->infof("Generating license file\n");
    path('LICENSE')->spew($self->license->fulltext);

    # Generate meta file
    {
        my $dat = {
            "meta-spec" => {
                "version" => "2",
                "url"     => "http://search.cpan.org/perldoc?CPAN::Meta::Spec"
            },
        };

        $dat->{abstract} = $self->config->{abstract};
        $dat->{author} = [$self->config->{author}];
        $dat->{dynamic_config} = 0;
        $dat->{license} = $self->license->meta2_name;
        $dat->{version} = $self->config->{version};
        $dat->{name} = $self->config->{name};
        $dat->{prereqs} = $self->prereq_specs;
        $dat->{generated_by} = "Minya/$Minya::VERSION";
        path('META.yml')->spew(YAML::Tiny::Dump(CPAN::Meta::Converter->new($dat)->convert(version => 1.4)));
        path('META.json')->spew(JSON::PP->new->indent->encode(CPAN::Meta::Converter->new($dat)->convert(version => 2)));
    }

    my @files = map { path($_)->relative($self->work_dir) } $self->gather_files($self->work_dir);

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
    $tar->add_files(@files);
    $tar->write(path($self->base_dir, $tarball), COMPRESS_GZIP);
    $self->infof("Wrote %s\n", $tarball);

    return $tarball;
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

    my @files = $self->gather_files($self->base_dir);

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
    $self->call_trigger('after_setup_workdir');

    return $guard;
}

sub gather_files {
    my ($self, $root) = @_;

    my $rule = Path::Iterator::Rule->new(
        relative => 1,
    );
    $rule->skip_vcs();
    $rule->skip_dirs('_build', '.build', 'blib');
    # skip blib
    $rule->skip(
        $rule->new->name(
            '.travis.yml',
            '.gitignore',
            '.DS_Store',
            qr/\A\..*\.sw[op]\z/, # vim swap files
            'MYMETA.yml',
            'MYMETA.json',
            '*.bak',
            sprintf("%s-*.tar.gz", $self->config->{name}),
        ),
    );
    $rule->all($root);
}

sub generate_build_pl {
    my ($self) = @_;

    my $config = $self->config();

    # TODO: Equivalent to M::I::GithubMeta is required?
    # TODO: ShareDir?

    # Should I use EU::MM instead of M::B?
    local $Data::Dumper::Terse = 1;
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
    license     => '<?= $self->license->meta_yml_name || "unknown" ?>',
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

