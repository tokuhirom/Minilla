package Minilla::Config;
use strict;
use warnings;
use utf8;
use TOML qw(from_toml);

use File::Basename qw(basename);
use Minilla::Metadata;
use Minilla::Util qw(module_name2path slurp_utf8);

use Moo;

has [qw(name abstract version perl_version author license metadata)] => (
    is => 'ro',
    required => 1,
);

# Optional things in minil.toml
has [qw(share_dir script_files homepage)] => (
    is => 'ro',
);

has [qw(license_meta2 dist_name)] => (
    is => 'lazy',
);

no Moo;

sub load {
    my ($class, $c, $path) = @_;

    my $conf;
    if (defined($path) && -f $path) {
        my $err;
        ($conf, $err) = from_toml(slurp_utf8($path));
        if ($err) {
            $c->error("TOML error in $path: $err");
        }

        unless ($conf->{name}) {
            $c->infof("Missing name in minil.toml. Detecting name from directory name.\n");
            $conf->{name} ||= do {
                local $_ = basename($c->base_dir);
                $_ =~ s!\Ap5-!!;
                $_;
            };
        }
    } else {
        $c->infof("There is no minil.toml. Detecting project name from directory name.\n");
        $conf->{name} ||= do {
            local $_ = basename($c->base_dir);
            $_ =~ s!\Ap5-!!;
            $_;
        };
    }

    my $module_name = $conf->{name}
        or $c->error("Cannot detect module name from minil.toml or directory name\n");

    # fill from main_module
    my $source_path = $class->detect_source_path($module_name);
    unless (-e $source_path) {
        $c->error(sprintf("%s not found.\n", $source_path));
    }
    my $metadata = Minilla::Metadata->new(
        source => $source_path,
    );
    $conf->{metadata} = $metadata;
    for my $key (qw(abstract version perl_version author license)) {
        $conf->{$key} ||= $metadata->$key()
            or $c->error("Missing $key in main_module");
    }

    $c->infof("Name: %s\n", $conf->{name});
    $c->infof("Abstract: %s\n", $conf->{abstract});
    $c->infof("Version: %s\n", $conf->{version});

    if ($conf->{version} =~ /\A[0-9]+\.[0-9]+\.[0-9]+\z/) {
        $conf->{version} = 'v' . $conf->{version};
    }

    return $class->new($conf);
}

sub _build_license_meta2 {
    my ($self) = @_;
    +{
        Perl_5 => 'perl_5',
        unknown => 'unknown',
    }->{$self->license} or die "Unknown license: $self->{license}";
}

sub _build_dist_name {
    my $self = shift;

    my $dist_name = $self->name;
    $dist_name =~ s!::!-!g;
    $dist_name;
}

sub _module_name2path {
    local $_ = shift;
    s!::!/!;
    s!-!/!;
    "lib/$_.pm";
}

use File::Glob qw(:bsd_glob);
sub detect_source_path {
    my ($self, $module_name) = @_;
    my $path = _module_name2path($module_name);
    return $path if -f $path;

    # search modules in case sensitive rule.
    $path = bsd_glob($path, GLOB_NOCASE);
    return $path if -f $path;

    return undef;
}

1;

