package Minilla::Metadata;
use strict;
use warnings;
use utf8;
use Minilla::Util qw(slurp require_optional);
use Carp;
use Module::Metadata;

use Moo;

has [qw(abstract perl_version author license)] => (
    is => 'lazy',
);

has metadata => (
    is => 'lazy',
    handles => [qw(name version)],
);

has source => (
    is => 'rw',
    isa => sub {
        defined $_[0] or Carp::confess("source should not be undef");
        -f $_[0] or Carp::confess("source file not found: '$_[0]'");
    },
    required => 1,
);

no Moo;

sub _build_metadata {
    my $self = shift;
    Module::Metadata->new_from_file($self->source, collect_pod => 1);
}

# Taken from Module::Install::Metadata
sub _build_abstract {
    my ($self) = @_;
    require ExtUtils::MM_Unix;
    bless( { DISTNAME => $self->name }, 'ExtUtils::MM_Unix' )->parse_abstract($self->source);
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
 
sub _build_perl_version {
    my ($self) = @_;

    my $perl_version = _extract_perl_version(slurp($self->source));
    if ($perl_version) {
        return $perl_version;
    } else {
        return;
    }
}

sub _build_author {
    my ($self) = @_;

    my $content = slurp($self->source);
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


#Stolen from M::B
sub _is_perl5_license {
    my $pod = shift;
    my $matched;
    return __extract_license(
        ($matched) = $pod =~ m/
            (=head \d \s+ L(?i:ICEN[CS]E|ICENSING)\b.*?)
            (=head \d.*|=cut.*|)\z
        /xms
    ) || __extract_license(
        ($matched) = $pod =~ m/
            (=head \d \s+ (?:C(?i:OPYRIGHTS?)|L(?i:EGAL))\b.*?)
            (=head \d.*|=cut.*|)\z
        /xms
    );
}
 
sub __extract_license {
    my $license_text = shift or return;
    my @phrases      = (
        '(?:under )?the same (?:terms|license) as (?:perl|the perl (?:\d )?programming language)',
        '(?:under )?the terms of (?:perl|the perl programming language) itself',
        'Artistic and GPL'
    );
    for my $pattern (@phrases) {
        $pattern =~ s#\s+#\\s+#gs;
        if ( $license_text =~ /\b$pattern\b/i ) {
            return 1;
        }
    }
    return 0;
}

sub _build_license {
    my ($self) = @_;

    my $pm_text = slurp($self->source);
    if (_is_perl5_license($pm_text)) {
        require Minilla::License::Perl_5;
        return Minilla::License::Perl_5->new({
            holder => $self->author,
        });
    } else {
        require_optional('Software/LicenseUtils.pm', 'Non Perl_5 license support');
        my (@guesses) = Software::LicenseUtils->guess_license_from_pod($pm_text);
        if (@guesses) {
            my $klass = $guesses[0];
            eval "require $klass; 1" or die $@; ## no critic.
            $klass->new({
                holder => $self->author,
            });
        } else {
            warn "Cannot determine license info from $_[0]\n";
            require Software::License::None;
            return Software::License::None->new({
                holder => $self->author,
            });
        }
    }
}

1;

