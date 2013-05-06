package Minilla::Metadata;
use strict;
use warnings;
use utf8;
use Minilla::Util qw(slurp slurp_utf8 require_optional);
use Carp;
use Module::Metadata;
use Minilla::License::Perl_5;
use Pod::Escapes;

use Moo;

has [qw(abstract perl_version authors license)] => (
    is => 'lazy',
);

has '_license_name' => (
    is => 'ro',
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

    # find by EU::MM
    {
        require ExtUtils::MM_Unix;
        my $abstract = bless( { DISTNAME => $self->name }, 'ExtUtils::MM_Unix' )->parse_abstract($self->source);
        return $abstract if $abstract;
    }
    # Parsing pod with Module::Metadata
    {
        my $name = $self->metadata->pod('NAME');
        $name =~ s/^\s+//gxsm;
        $name =~ s/\s+$//gxsm;
        my ($pkg, $abstract) = split /\s+-\s+/, $name, 2;
        return $abstract if $abstract;
    }
    # find dzil style '# ABSTRACT: '
    {
        if (slurp($self->source) =~ /^\s*#+\s*ABSTRACT:\s*(.+)$/m) {
            return $1;
        }
    }
    return;
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

sub _build_authors {
    my ($self) = @_;

    my $content = slurp_utf8($self->source);
    if ($content =~ m/
        =head \d \s+ (?:authors?)\b \s*
        ([^\n]*)
        |
        =head \d \s+ (?:licen[cs]e|licensing|copyright|legal)\b \s*
        .*? copyright .*? \d\d\d[\d.]+ \s* (?:\bby\b)? \s*
        ([^\n]*)
    /ixms) {
        my $author = $1 || $2;
 
        $author =~ s{ E<( (\d+) | ([A-Za-z]+) )> }{
            defined $2
            ? chr($2)
            : defined $Pod::Escapes::Name2character_number{$1}
            ? chr($Pod::Escapes::Name2character_number{$1})
            : do {
                warn "Unknown escape: E<$1>";
                "E<$1>";
            };
        }gex;

        my @authors;
        for (split /\n/, $author) {
            chomp;
            next unless /\S/;
            push @authors, $_;
        }
        return \@authors;
    } else {
        warn "Cannot determine author info from @{[ $_[0]->source ]}\n";
        return undef;
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

sub _guess_license_class_by_name {
    my ($name) = @_;

    if ($name eq 'Perl_5') {
        return 'Minilla::License::Perl_5'
    } else {
        my $meta_str = qq!{"license":"$name"}!;
        require_optional('Software/LicenseUtils.pm', 'Non Perl_5 license support');
        my (@guesses) = Software::LicenseUtils->guess_license_from_meta($meta_str);
        unless (@guesses) {
            Carp::confess("License $name is not supported yet.");
        }
        my $klass = shift @guesses;
        eval "require $klass; 1" or die $@; ## no critic.
        return $klass;
    }
}

sub _build_license {
    my ($self) = @_;

    my $pm_text = slurp($self->source);
    my $holder = $self->authors ? $self->authors->[0] : 'Unknown';
    if ($self->_license_name) {
        _guess_license_class_by_name($self->_license_name)->new({
            holder => $holder,
        });
    } elsif (_is_perl5_license($pm_text)) {
        require Minilla::License::Perl_5;
        return Minilla::License::Perl_5->new({
            holder => $holder,
        });
    } else {
        if (eval "require Software::LicenseUtils; 1") {
            my (@guesses) = Software::LicenseUtils->guess_license_from_pod($pm_text);
            if (@guesses) {
                my $klass = $guesses[0];
                eval "require $klass; 1" or die $@; ## no critic.
                $klass->new({
                    holder => $holder,
                });
            } else {
                warn "Cannot determine license info from @{[ $_[0]->source ]}\n";
                require Minilla::License::Unknown;
                return Minilla::License::Unknown->new({
                    holder => $holder,
                });
            }
        } else {
            warn "Software::License is needed when you want to use non Perl_5 license.\n";
            require Minilla::License::Unknown;
            return Minilla::License::Unknown->new({
                holder => $holder,
            });
        }
    }
}

1;

