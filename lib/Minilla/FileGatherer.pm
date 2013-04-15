package Minilla::FileGatherer;
use strict;
use warnings;
use utf8;
use File::pushd;
use File::Spec;
use File::Basename;

use Minilla::Git;

use Moo;

has exclude_match => (
    is => 'ro',
    default => sub { +[ ] },
);

has include_dotfiles => (
    is => 'ro',
    default => sub { undef },
);

no Moo;

sub gather_files {
    my ($self, $root) = @_;
    my $guard = pushd($root);
    my @files = grep { _topdir($_) ne 'extlib' }
                grep { not -l $_ }
                map { File::Spec->abs2rel($_, $root) }
                git_ls_files();
    if ($self->exclude_match) {
        for my $pattern (@{$self->exclude_match || []}) {
            @files = grep { _normalize($_) !~ $pattern } @files;
        }
    }

    unless ($self->include_dotfiles) {
        @files = grep { basename($_) !~ qr/^\./ } @files;
    }

    return @files;
}

sub _topdir {
    my ($path) = @_;
    [File::Spec->splitdir($path)]->[0] || '';
}

# for Windows
sub _normalize {
    local $_ = shift;
    s!\\!/!g;
    $_;
}

1;
