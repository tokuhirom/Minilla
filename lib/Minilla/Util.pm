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
use IPC::Open3 ();
use Symbol qw(gensym);

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

    my $exit_status;
    if (!$ENV{TEST_VERBOSE}) {
        open(my $devnull, '+>', File::Spec->devnull);
        my $pid = IPC::Open3::open3(gensym, $devnull, $devnull, @_);
        waitpid($pid, 0);
        $exit_status = $? >> 8;
    } else {
        $exit_status = system(@_);
    }
    Minilla::Logger::errorf("Giving up.\n") if $exit_status != 0;
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

1;

