package Minilla::Git;
use strict;
use warnings;
use utf8;

use parent qw(Exporter);

our @EXPORT = qw(git_ls_files git_init git_add git_rm git_commit git_config git_remote git_submodule_add git_submodules git_submodule_files);

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

sub git_remote {
    cmd('git', 'remote', @_);
}

sub git_ls_files {
    my @files = split /\0/, `git ls-files -z`;
    return @files;
}

sub git_submodule_add {
    cmd('git', 'submodule', 'add', @_);
}

sub git_submodules {
    my @submodules = split /\n/, `git submodule status`;
    my @files;
    for (@submodules) {
        my ($path) = $_ =~ /^[+\-U\x20][0-9a-f]{40}\x20([^\x20]+).*$/;
        push @files, $path if $path;
    }
    return @files;
}

sub git_submodule_files {
    my @output = split /\n/, `git submodule foreach git ls-files -z`;
    my @files;
    while (@output) {
        my $submodule_line = shift @output;
        my ($submodule_name) = $submodule_line =~ /'(.+)'/;
        push @files, map "$submodule_name/$_", split /\0/, shift @output;
    }
    return @files;
}

1;

