package Minilla::Git;
use strict;
use warnings;
use utf8;

use parent qw(Exporter);

our @EXPORT = qw(git_ls_files git_init git_add git_rm git_commit git_config);

use Minilla::Util qw(cmd);

sub git_init {
    cmd('git', 'init');
}

sub git_add {
    cmd('git', 'add', @_ ? @_ : '.');
}

sub git_config {
    cmd('git', 'config', @_ ? @_ : '.');
}

sub git_rm {
    cmd('git', 'rm', @_);
}

sub git_commit {
    cmd('git', 'commit', @_);
}

sub git_ls_files {
    my @files = split /\0/, `git ls-files -z`;
    return @files;
}

1;

