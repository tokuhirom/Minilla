use strict;
use warnings;
use utf8;
use Test::More;
use File::Temp qw(tempdir);
use File::pushd;

use Minilla::Migrate;

subtest 'pp project' => sub {
    my $tmp = tempdir(CLEAN => 1);
    my $guard = pushd($tmp);
    my $migrate = Minilla::Migrate->new();
    ok(not $migrate->needs_module_build);
};

subtest 'xs project' => sub {
    my $tmp = tempdir(CLEAN => 1);
    my $guard = pushd($tmp);

    open my $fh, '>', 'foo.xs'
        or die $!;
    print $fh "XXX";
    close $fh;

    my $migrate = Minilla::Migrate->new();
    ok($migrate->needs_module_build);
};

done_testing;

