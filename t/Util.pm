package t::Util;
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

$Minilla::DEBUG=1 if $ENV{MINILLA_DEBUG};

plan skip_all => "No git command" unless which('git');
plan skip_all => "No cpanm command" unless which('cpanm');
plan skip_all => "No git configuration" unless `git config user.email` =~ /\@/;
$ENV{PERL_CPANM_HOME} = tempdir();

our @EXPORT = (
    qw(git_init_add_commit git_create_checkout_branch write_minil_toml),
    qw(tempdir pushd),
    @Minilla::Git::EXPORT, @Minilla::Util::EXPORT_OK, qw(spew),
    qw(catfile),
    qw(mkpath),
);

sub git_init_add_commit() {
    git_init();
    git_add('.');
    git_commit('-m', 'initial import');
}

sub git_create_checkout_branch() {
    my $branch = 'new-branch';
    git_branch($branch);
    git_checkout($branch);
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

1;

