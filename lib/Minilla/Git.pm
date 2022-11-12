package Minilla::Git;
use strict;
use warnings;
use utf8;

use parent qw(Exporter);

our @EXPORT = qw(git_ls_files git_init git_add git_rm git_commit git_config git_remote git_submodules git_submodule_files git_show_toplevel);

use Minilla::Logger qw(errorf);
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

sub git_submodules {
    my @submodules = split /\n/, `git submodule status --recursive`;
    my @files;
    for (@submodules) {
        my ($path) = $_ =~ /^[+\-U\x20][0-9a-f]{40}\x20([^\x20]+).*$/;
        push @files, $path if $path;
    }
    return @files;
}

sub git_submodule_files {
    # XXX: `git ls-files -z` does *NOT* print new line in last.
    #      So it breaks format when multiple submodules contains and combined with `git submodule foreach`. (and failed to parse.)
    my @output = split /\n/, `git submodule foreach --recursive "git ls-files -z"`;
    for (my $i = 1; $i <= @output-2; $i += 2) {
        $output[$i] =~ s/\0([^\0]*)$//;
        splice @output, $i+1, 0, $1;
    }

    my @files;
    while (@output) {
        my $submodule_line = shift @output;
        my ($submodule_name) = $submodule_line =~ /'(.+)'/;
        push @files, map "$submodule_name/$_", split /\0/, shift @output;
    }
    return @files;
}

sub git_show_toplevel {
    my $top_level = `git rev-parse --show-toplevel`;
    if ( $? != 0 ) {
        errorf("Top-level git directory could not be found for %s: %s\n", Cwd::getcwd(),
               $? == -1 ? "$!" :
               $? & 127 ? "git received signal ". ($? & 127) : "git exited ". ($? >> 8))
    }
    chomp $top_level;
    return $top_level;
}

1;
