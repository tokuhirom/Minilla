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
    ok(!$migrate->use_mb_tiny);
};

subtest 'xs project' => sub {
    my $tmp = tempdir(CLEAN => 1);
    my $guard = pushd($tmp);

    open my $fh, '>', 'foo.xs'
        or die $!;
    print $fh "XXX";
    close $fh;

    my $migrate = Minilla::Migrate->new();
    ok($migrate->use_mb_tiny);
};

done_testing;

