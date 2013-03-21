package Minya::Config;
use strict;
use warnings;
use utf8;
use TOML qw(from_toml);

use Minya::Metadata;
use Minya::Util qw(module_name2path slurp_utf8);

use Moo;

has [qw(name abstract version perl_version author license metadata)] => (
    is => 'ro',
    required => 1,
);

# Optional things in minya.toml
has [qw(share_dir script_files homepage)] => (
    is => 'ro',
);

has [qw(license_meta2 dist_name)] => (
    is => 'lazy',
);

no Moo;

sub load {
    my ($class, $c, $path) = @_;

    my ($conf, $err) = from_toml(slurp_utf8($path));
    if ($err) {
        $c->error("TOML error in $path: $err");
    }

    # validation
    my $module_name = $conf->{name} || $c->error("Missing name in minya.toml\n");

    # fill from main_module
    my $metadata = Minya::Metadata->new(
        source => module_name2path($module_name),
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

1;

