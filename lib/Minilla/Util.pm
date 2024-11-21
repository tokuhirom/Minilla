package Minilla::Util;
use strict;
use warnings;
use utf8;
use Carp ();
use File::Basename ();
use File::Spec ();
use File::Which 'which';
use Minilla::Logger ();
use Getopt::Long ();
use Cwd();

use parent qw(Exporter);

our @EXPORT_OK = qw(
    find_dir find_file
    randstr
    slurp slurp_utf8 slurp_raw
    spew  spew_utf8  spew_raw
    edit_file require_optional
    cmd cmd_perl
    pod_escape
    parse_options
    check_git
    guess_license_class_by_name
);

our %EXPORT_TAGS = (
    all => \@EXPORT_OK
);

sub randstr {
    my $len = shift;
    my @chars = ("a".."z","A".."Z",0..9);
    my $ret = '';
    join('', map { $chars[int(rand(scalar(@chars)))] } 1..$len);
}

sub slurp {
    my $fname = shift;
    open my $fh, '<', $fname
        or Carp::croak("Can't open '$fname' for reading: '$!'");
    scalar do { local $/; <$fh> }
}

sub slurp_utf8 {
    my $fname = shift;
    open my $fh, '<:encoding(UTF-8)', $fname
        or Carp::croak("Can't open '$fname' for reading: '$!'");
    scalar do { local $/; <$fh> }
}

sub slurp_raw {
    my $fname = shift;
    open my $fh, '<:raw', $fname
        or Carp::croak("Can't open '$fname' for reading: '$!'");
    scalar do { local $/; <$fh> }
}

sub spew($$) {
    my $fname = shift;
    open my $fh, '>', $fname
        or Carp::croak("Can't open '$fname' for writing: '$!'");
    print {$fh} $_[0];
}

sub spew_raw {
    my $fname = shift;
    open my $fh, '>:raw', $fname
        or Carp::croak("Can't open '$fname' for writing: '$!'");
    print {$fh} $_[0];
}

sub spew_utf8 {
    my $fname = shift;
    open my $fh, '>:encoding(UTF8)', $fname
        or Carp::croak("Can't open '$fname' for writing: '$!'");
    print {$fh} $_[0];
}

sub edit_file {
    my ($file) = @_;
    my $editor = $ENV{"EDITOR"} || "vi";
    system( $editor, $file );
}

sub find_file {
    my ($file) = @_;

    my $dir = Cwd::getcwd();
    my %seen;
    while ( -d $dir ) {
        return undef if $seen{$dir}++;    # guard from deep recursion
        if ( -f "$dir/$file" ) {
            return "$dir/$file";
        }
        $dir = File::Basename::dirname($dir);
    }

    return undef;
}

sub find_dir {
    my ($file) = @_;

    my $dir = Cwd::getcwd();
    my %seen;
    while ( -d $dir ) {
        return undef if $seen{$dir}++;    # guard from deep recursion
        if ( -d "$dir/$file" ) {
            return "$dir/$file";
        }
        $dir = File::Basename::dirname($dir);
    }

    return undef;
}

sub require_optional {
    my ( $file, $feature, $library ) = @_;

    return if exists $INC{$file};
    unless ( eval { require $file } ) {
        if ( $@ =~ /^Can't locate/ ) {
            $library ||= do {
                local $_ = $file;
                s/ \.pm \z//xms;
                s{/}{::}g;
                $_;
            };
            Carp::croak( "$feature requires $library, but it is not available."
                  . " Please install $library using your preferred CPAN client" );
        }
        else {
            die $@;
        }
    }
}

sub cmd_perl {
    my(@args) = @_;

    my @abs_inc = map { $_ eq '.' ? $_ : File::Spec->rel2abs($_) }
                      @INC;

    cmd($^X, (map { "-I$_" } @abs_inc), @args);
}

sub cmd {
    Minilla::Logger::infof("[%s] \$ %s\n", File::Basename::basename(Cwd::getcwd()), "@_");
    system(@_) == 0
        or Minilla::Logger::errorf("Giving up.\n");
}

sub parse_options {
    my ( $args, @spec ) = @_;
    Getopt::Long::GetOptionsFromArray( $args, @spec );
}

sub pod_escape {
    local $_ = shift;
    my %POD_ESCAPE = ( '<' => 'E<lt>', '>' => 'E<gt>' );
    s!([<>])!$POD_ESCAPE{$1}!ge;
    $_;
}

sub check_git {
    unless (which 'git') {
        Minilla::Logger::errorf("The \"git\" executable has not been found.\n");
    }
}

sub guess_license_class_by_name {
    my ($name) = @_;

    if ($name eq 'Perl_5') {
        return 'Minilla::License::Perl_5';
    } else {
        my %license_map = (
            'agpl_3'       => 'Software::License::AGPL_3',
            'apache_1_1'   => 'Software::License::Apache_1_1',
            'apache_2_0'   => 'Software::License::Apache_2_0',
            'artistic_1'   => 'Software::License::Artistic_1_0',
            'artistic_2'   => 'Software::License::Artistic_2_0',
            'bsd'          => 'Software::License::BSD',
            'unrestricted' => 'Software::License::CC0_1_0',
            'custom'       => 'Software::License::Custom',
            'freebsd'      => 'Software::License::FreeBSD',
            'gfdl_1_2'     => 'Software::License::GFDL_1_2',
            'gfdl_1_3'     => 'Software::License::GFDL_1_3',
            'gpl_1'        => 'Software::License::GPL_1',
            'gpl_2'        => 'Software::License::GPL_2',
            'gpl_3'        => 'Software::License::GPL_3',
            'lgpl_2_1'     => 'Software::License::LGPL_2_1',
            'lgpl_3_0'     => 'Software::License::LGPL_3_0',
            'mit'          => 'Software::License::MIT',
            'mozilla_1_0'  => 'Software::License::Mozilla_1_0',
            'mozilla_1_1'  => 'Software::License::Mozilla_1_1',
            'open_source'  => 'Software::License::Mozilla_2_0',
            'restricted'   => 'Software::License::None',
            'openssl'      => 'Software::License::OpenSSL',
            'perl_5'       => 'Software::License::Perl_5',
            'open_source'  => 'Software::License::PostgreSQL',
            'qpl_1_0'      => 'Software::License::QPL_1_0',
            'ssleay'       => 'Software::License::SSLeay',
            'sun'          => 'Software::License::Sun',
            'zlib'         => 'Software::License::Zlib',
        );
        if (my $klass = $license_map{lc $name}) {
            eval "require $klass; 1" or die "$klass is required for supporting $name license. But: $@"; ## no critic.
            return $klass;
        } else {
            die "'$name' is not supported yet. Supported licenses are: " . join(', ', keys %license_map);
        }
    }
}

1;
