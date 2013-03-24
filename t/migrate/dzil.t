use strict;
use warnings;
use utf8;
use Test::More;
use Minilla::CLI;
use File::Temp qw(tempdir);
use File::Copy::Recursive qw(rcopy);
use Minilla::Util qw(slurp);
use Module::CPANfile;

@INC = map { File::Spec->rel2abs($_) } @INC;

my $tmp = tempdir(CLEANUP => 0);
rcopy('t/migrate/dzil/' => $tmp);
my $dst = File::Spec->catdir($tmp, 'Acme-Dzil');
chdir $dst;
system('git init');
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

done_testing;

