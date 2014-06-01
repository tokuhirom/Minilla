package Module::BumpVersion;
use strict;
use warnings;
use utf8;

sub load {
    my ($class, $name) = @_;

    my $lines;
    my $is_perl = sub {
        return 1 if $name =~ m{ [.] (?i: pl | pm | t ) $ }x;
        $lines = $class->read_file($name);
        return 1 if @$lines && $lines->[0] =~ m{ ^ \#\! .* perl }ix;
        return;
    }->();
    $lines ||= $class->read_file($name);
    return unless $is_perl;
    return unless $lines;

    bless {lines => $lines, name => $name}, $class;
}

sub read_file {
    my ($class, $name) = @_;
    open my $fh, '<:raw', $name
        or die "Cannot open '$name' for readding: $!";
    my @ret = <$fh>;
    close $fh;
    return \@ret;
}

sub set_version {
    my ($self, $new_version) = @_;

    my $versions = $self->versions;
    my @lines = @{$self->{lines}};
    my $dirty;
    for my $edits ( values %$versions ) {
        for my $edit (@$edits) {
            $lines[ $edit->{line} ] =
              $edit->{pre} . $new_version . $edit->{post} . "\n";
            $dirty++;
        }
    }
    return unless $dirty;

    open my $fh, '>:raw', $self->{name}
        or die "Cannot open '$self->{name}' for writing: $!";
    print {$fh} $_ for @lines;
    close $fh;
}

sub find_version {
    my $self = shift;
    my ($version) = keys %{$self->versions};
    return $version;
}

sub versions {
    my $self = shift;
    $self->{versions} ||= $self->_find_version_for_doc();
}

sub _find_version_for_doc {
    my ( $self ) = @_;

    my $name = $self->{name};

    my $machine = $self->scanner();
    my $state = $machine->{init};
    my $lines = $self->{lines};
    my $ver_found = {};

  LINE:
    for my $ln ( 0 .. @$lines - 1 ) {
        my $line = $lines->[$ln];

        next LINE if $line =~ /# No BumpVersion/;

        # Bail out when we're in a state with no possible actions.
        last LINE unless @$state;

      STATE: {
            for my $trans (@$state) {
                if ( my @match = $line =~ $trans->{re} ) {
                    if ( $trans->{mark} ) {
                        my $ver = $2 . $3 . $4;
                        push @{ $ver_found->{ $ver } },
                          {
                            file => $name,
                            info => $self,
                            line => $ln,
                            pre  => $1,
                            ver  => $ver,
                            post => $5
                          };
                    }

                    if ( my $code = $trans->{exec} ) {
                        $code->( $machine, \@match, $line );
                    }

                    if ( my $goto = $trans->{goto} ) {
                        $state = $machine->{$goto};
                        redo STATE;
                    }
                }
            }
        }
    }
    return $ver_found;
}

sub version_re_perl {
    my $ver_re = shift;

    return qr{ ^ ( .*?  [\$\*] (?: \w+ (?: :: | ' ) )* VERSION \s* =
                    \D*? ) 
                 $ver_re 
                 ( .* ) $ }x;
}

sub version_re_pod {
    my $ver_re = shift;
    return qr{ ^ ( .*? (?i: version ) .*? ) $ver_re ( .* ) $ }x;
}


# State machine for Perl source
sub scanner{
    # Perl::Version::REGEX
    my $ver_re = qr/ ( (?i: Revision: \s+ ) | v | )
                     ( \d+ (?: [.] \d+)* )
                     ( (?: _ \d+ )? ) /x;

    {
        init => [
            {
                re   => qr{ ^ = (?! cut ) }x,
                goto => 'pod',
            },
            {
                re   => version_re_perl($ver_re),
                mark => 1,
            },
        ],

        # pod within perl
        pod => [
            {
                re   => qr{ ^ =head\d\s+VERSION\b }x,
                goto => 'version',
            },
            {
                re   => qr{ ^ =cut }x,
                goto => 'init',
            },
        ],

        # version section within pod
        version => [
            {
                re   => qr{ ^ = (?! head\d\s+VERSION\b ) }x,
                goto => 'pod',
            },
            {
                re   => version_re_pod($ver_re),
                mark => 1,
            },

        ],
    };
}


1;

