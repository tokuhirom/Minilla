package Minilla::Metadata::PodParser;
use strict;
use warnings;
use utf8;
use 5.008001;
use parent qw(Pod::Simple);

use constant {
    MODE_UNKNOWN => 0,
    MODE_HEAD1   => 1,
    MODE_NAME    => 2,
};

sub abstract {
    my $self = shift;
    $self->{abstract};
}

my ($STATE_DEFAULT, $STATE_HEAD1, $STATE_NAME);
{
    $STATE_DEFAULT = Minilla::Metadata::PodParser::State->new(
        start => sub {
            my ($self, $parser, $type) = @_;
            $STATE_HEAD1;
        }
    );
    $STATE_HEAD1 = Minilla::Metadata::PodParser::State->new(
        text => sub {
            my ($self, $parser, $text) = @_;
            if ($text eq 'NAME') {
                $STATE_NAME;
            }
        },
        end => sub {
            my ($self, $parser, $type) = @_;
            if ($type eq 'head1') {
                $STATE_DEFAULT
            }
        },
    );
    $STATE_NAME = Minilla::Metadata::PodParser::State->new(
        text => sub {
            my ($self, $parser, $text) = @_;
            my ($package, $abstract) = split /\s+-\s+/, $text, 2;
            $parser->{package} = $package;
            $parser->{abstract} = $abstract;
            $STATE_DEFAULT
        },
        end => sub {
            my ($self, $parser, $type) = @_;
        },
    );
}

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{state} = $STATE_DEFAULT;
    $self;
}

sub _handle_element_start {
    my $self = shift;
    $self->{state}->start($self, @_);
}

sub _handle_text {
    my $self = shift;
    $self->{state}->text($self, @_);
}

sub _handle_element_end {
    my $self = shift;
    $self->{state}->end($self, @_);
}

package # hide from PAUSE
    Minilla::Metadata::PodParser::State;

sub new {
    my $class = shift;
    my %args = @_==1 ? %{$_[0]} : @_;
    bless { %args }, $class;
}

for my $method (qw(start text end)) {
    no strict 'refs';
    *{__PACKAGE__ . "::$method"} = sub {
        my $self = shift;
        my $parser = shift;
        if ($self->{$method}) {
            my $state = $self->{$method}->($self, $parser, @_);
            if (UNIVERSAL::isa($state, 'Minilla::Metadata::PodParser::State')) {
                $parser->{state} = $state;
            }
        }
    };
}

1;

