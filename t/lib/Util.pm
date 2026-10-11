package Util;
use strict;
use warnings;
use utf8;
use parent qw(Exporter);

use File::pushd;
use File::Temp qw(tempdir);
use Test::More;
use File::Path;
use File::Which qw(which);
use File::Spec::Functions qw(catfile);
use TOML 0.92 qw(to_toml);

use Minilla;
use Minilla::Git;
use Minilla::Util qw/:all/;
use TOML;
use IPC::Open3 ();
use POSIX qw(WNOHANG);

$Minilla::DEBUG=1 if $ENV{MINILLA_DEBUG};

plan skip_all => "No git command" unless which('git');
plan skip_all => "No cpanm command" unless which('cpanm');
plan skip_all => "No git configuration" unless `git config user.email` =~ /\@/;
$ENV{PERL_CPANM_HOME} = tempdir(CLEANUP => 1);
delete $ENV{GIT_CONFIG};

our @EXPORT = (
    qw(git_init_add_commit git_submodule_add git_submodule_update_init_recursive write_minil_toml),
    qw(tempdir pushd),
    @Minilla::Git::EXPORT, @Minilla::Util::EXPORT_OK, qw(spew),
    qw(catfile),
    qw(mkpath),
    qw(run_with_open_stdin),
);

sub git_init_add_commit() {
    git_init();
    git_add('.');
    git_commit('-m', 'initial import');
}

# Cloning from local file system is disabled by default since git 2.38.1
# So set 'protocol.file.allow=always'
# - https://github.blog/2022-10-18-git-security-vulnerabilities-announced/#cve-2022-39253
sub git_submodule_add {
    cmd('git', '-c', 'protocol.file.allow=always', 'submodule', 'add', @_);
}

sub git_submodule_update_init_recursive {
    cmd('git', '-c', 'protocol.file.allow=always', 'submodule', 'update', '--init', '--recursive');
}

sub write_minil_toml {
    if ( @_ == 1 && !ref $_[0] ) {
        my $name = shift;
        $name =~ s/::/-/g;
        spew( 'minil.toml', qq{name = "$name"\n} );
    }
    else {
        spew( 'minil.toml', to_toml(@_) );
    }
}

sub run_with_open_stdin {
    my ($timeout, @command) = @_;
    my $dir = tempdir(CLEANUP => 1);
    my $log_path = catfile($dir, 'output.log');
    open my $log, '>', $log_path or die "Cannot open child output: $!";
    local *STDIN;
    open STDIN, '<', File::Spec->devnull or die "Cannot open null input: $!";
    my $pid = IPC::Open3::open3(
        my $input, '>&' . fileno($log), '>&' . fileno($log), @command,
    );
    my $deadline = time + $timeout;
    my $status;
    while (1) {
        my $result = waitpid $pid, WNOHANG;
        if ($result == $pid) {
            $status = $?;
            last;
        }
        die "Cannot wait for child $pid: $!" if $result == -1;
        if (time >= $deadline) {
            kill 'KILL', $pid;
            waitpid $pid, 0;
            die "Child $pid did not exit with its input pipe open within $timeout seconds\n";
        }
        select undef, undef, undef, 0.05;
    }
    close $input or die "Cannot close child input: $!";
    close $log or die "Cannot close child output: $!";
    return ($status, slurp($log_path));
}

1;
