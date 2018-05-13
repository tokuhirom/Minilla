use strict;
use warnings;
use utf8;
use Test::More;
use lib "t/lib";
use Util;
use Test::Requires {
    'Dist::Zilla' => 4.300039
};
use File::Which;
use Cwd 'getcwd';

plan skip_all => "No dzil command" unless which 'dzil';
plan skip_all => "No git configuration" unless `git config user.email` =~ /\@/;

use Minilla::CLI;
use File::Temp qw(tempdir);
use File::Copy::Recursive qw(rcopy);
use Minilla::Util qw(slurp);
use Module::CPANfile;
use Minilla::Git;

@INC = map { File::Spec->rel2abs($_) } @INC;

my $tmp = tempdir(CLEANUP => 1);
rcopy('t/migrate/dzil/' => $tmp);
my $dst = File::Spec->catdir($tmp, 'Acme-Dzil');
my $cwd = getcwd;
chdir $dst;
git_init();
git_add('.');
git_commit('-m', 'initial import');

Minilla::CLI->new()->run('migrate');

{
    my $cpanfile = Module::CPANfile->load('cpanfile');
    ok(not exists $cpanfile->prereq_specs->{configure}->{requires}->{'ExtUtils::MakeMaker'});
}

ok(-f 'Build.PL');
for (qw(Build.PL cpanfile minil.toml)) {
    note "--------- $_\n";
    note slurp($_);
}

chdir $cwd; # this is need for File::Temp
done_testing;

