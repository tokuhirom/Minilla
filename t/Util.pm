package t::Util;
use strict;
use warnings;
use utf8;
use parent qw(Exporter);

use File::pushd;
use File::Temp qw(tempdir);
use Test::More;
use File::Path;

use Minilla;
use Minilla::Git;
use Minilla::Util qw/:all/;

plan skip_all => "No git configuration" unless `git config user.email` =~ /\@/;

our @EXPORT = (
    qw(git_init_add_commit),
    qw(tempdir pushd),
    @Minilla::Git::EXPORT, @Minilla::Util::EXPORT_OK, qw(spew),
    qw(mkpath),
);

sub git_init_add_commit() {
    git_init();
    git_add('.');
    git_commit('-m', 'initial import');
}

1;

