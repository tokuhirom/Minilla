package Minya::Metadata;
use strict;
use warnings;
use utf8;
use Minya::Util qw(slurp);

# Taken from Module::Install::Metadata
sub name {
    my ($class, $file) = @_;

    if (
        slurp($file) =~ m/
        ^ \s*
        package \s*
        ([\w:]+)
        \s* ;
        /ixms
    ) {
        my ($name, $module_name) = ($1, $1);
        $name =~ s{::}{-}g;
        return wantarray ? ($name, $module_name) : $name;
    } else {
        die("Cannot determine name from $file\n");
    }
}

sub abstract {
    my ($class, $name, $file) = @_;
    require ExtUtils::MM_Unix;
    bless( { DISTNAME => $name }, 'ExtUtils::MM_Unix' )->parse_abstract($file);
}

sub version {
    my ($class, $file) = @_;
    ExtUtils::MM_Unix->parse_version($file);
}


sub _extract_perl_version {
    if (
        $_[0] =~ m/
        ^\s*
        (?:use|require) \s*
        v?
        ([\d_\.]+)
        \s* ;
        /ixms
    ) {
        my $perl_version = $1;
        $perl_version =~ s{_}{}g;
        return $perl_version;
    } else {
        return;
    }
}

 
sub perl_version_from {
    my ($class, $file) = @_;

    my $perl_version = _extract_perl_version(slurp($file));
    if ($perl_version) {
        return $perl_version;
    } else {
        return;
    }
}

1;

