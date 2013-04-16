package Dist::BumpVersion;
use strict;
use warnings;
use utf8;
use Perl::Version;
use Getopt::Long;
use Pod::Usage;
use File::Spec;
use File::Basename;
use Dist::BumpVersion::Perl;
use File::Find;

sub new {
    my ($class, $dir) = @_;
    my $self = bless {dir => $dir}, $class;
    $self->{files} = [grep { $_ } map { Dist::BumpVersion::Perl->load($_) } $self->find_files($dir)];
    return $self;
}

sub bump_version {
    my ($self) = @_;
    my $dir = $self->{dir};

    my $new_ver = $self->find_version()
        or return;
    $new_ver = Perl::Version->new($new_ver);
    if ( $new_ver->is_alpha ) {
        $new_ver->inc_alpha;
    }
    else {
        my $pos = $new_ver->components - 1;
        $new_ver->increment($pos);
    }
    $self->set_version($new_ver);
    return $new_ver;
}

sub find_version {
    my ($self) = @_;

    my %versions;
    for my $file (@{$self->{files}}) {
        $versions{$_}++ for keys %{$file->versions};
    }

    my @got = sort keys %versions;
    my $version;
    if ( @got == 0 ) {
        $self->{errstr} = "Can't find any version strings";
    }
    elsif ( @got > 1 ) {
        my $buf = "Multiple versions found:\n";
        for my $file (@{$self->{files}}) {
            for my $version (keys %{$file->versions}) {
                $buf .= "    @{[ $file->{name} ]}: $version\n";
            }
        }
        $self->{errstr} = $buf;
    } else {
        ($version, ) = keys %versions;
    }

    return $version;
}

sub errstr { $_[0]->{errstr} }

sub set_version {
    my ($self, $version) = @_;

    for my $file (@{$self->{files}}) {
        $file->set_version($version);
    }
}

sub find_files {
    my ($self, $top) = @_;
    Carp::croak("Missing mandatory parameter: top") unless defined $top;

    my @out;
    File::Find::find(
        {
            wanted => sub {
                return if -l $_; # symlink
                return if !-f $_;

                my $topdir = [File::Spec->splitdir(File::Spec->abs2rel($_, $top))]->[0];
                return if $topdir eq 'blib';
                return if $topdir eq 'author';
                return if $topdir eq '.build';
                return if $topdir eq '_build';
                # build dir
                return if -f File::Spec->catfile([File::Spec->splitdir($_)]->[1], 'META.json');
                push @out, $_;
            },
            no_chdir => 1,
        }, $top
    );
    return @out;
}

1;

