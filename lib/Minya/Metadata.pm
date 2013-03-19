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
 
sub perl_version {
    my ($class, $file) = @_;

    my $perl_version = _extract_perl_version(slurp($file));
    if ($perl_version) {
        return $perl_version;
    } else {
        return;
    }
}


sub author {
    my ($self, $file) = @_;

    my $content = slurp($file);
    if ($content =~ m/
        =head \d \s+ (?:authors?)\b \s*
        ([^\n]*)
        |
        =head \d \s+ (?:licen[cs]e|licensing|copyright|legal)\b \s*
        .*? copyright .*? \d\d\d[\d.]+ \s* (?:\bby\b)? \s*
        ([^\n]*)
    /ixms) {
        my $author = $1 || $2;
 
        # XXX: ugly but should work anyway...
        if (eval "require Pod::Escapes; 1") { ## no critics.
            # Pod::Escapes has a mapping table.
            # It's in core of perl >= 5.9.3, and should be installed
            # as one of the Pod::Simple's prereqs, which is a prereq
            # of Pod::Text 3.x (see also below).
            $author =~ s{ E<( (\d+) | ([A-Za-z]+) )> }
            {
                defined $2
                ? chr($2)
                : defined $Pod::Escapes::Name2character_number{$1}
                ? chr($Pod::Escapes::Name2character_number{$1})
                : do {
                    warn "Unknown escape: E<$1>";
                    "E<$1>";
                };
            }gex;
        }
            ## no critic.
        elsif (eval "require Pod::Text; 1" && $Pod::Text::VERSION < 3) {
            # Pod::Text < 3.0 has yet another mapping table,
            # though the table name of 2.x and 1.x are different.
            # (1.x is in core of Perl < 5.6, 2.x is in core of
            # Perl < 5.9.3)
            my $mapping = ($Pod::Text::VERSION < 2)
                ? \%Pod::Text::HTML_Escapes
                : \%Pod::Text::ESCAPES;
            $author =~ s{ E<( (\d+) | ([A-Za-z]+) )> }
            {
                defined $2
                ? chr($2)
                : defined $mapping->{$1}
                ? $mapping->{$1}
                : do {
                    warn "Unknown escape: E<$1>";
                    "E<$1>";
                };
            }gex;
        }
        else {
            $author =~ s{E<lt>}{<}g;
            $author =~ s{E<gt>}{>}g;
        }
        return $author;
    } else {
        warn "Cannot determine author info from $_[0]\n";
        return;
    }
}

1;

