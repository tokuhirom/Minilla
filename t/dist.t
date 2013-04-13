use strict;
use warnings;
use utf8;
use Test::More;
use t::Util;

use File::Spec;
use File::Path;
use File::Copy::Recursive qw(rcopy);

use Minilla::Git;

my $minil = File::Spec->rel2abs('script/minil');

my @dists = @ARGV;
if (! @dists) {
    @dists = glob('test-dist/*');
}

foreach my $dist (@dists) {
    note "testing $dist";

    my $tempdir = tempdir(CLEANUP => 1, DIR => '.');

    rcopy($dist, "$tempdir/$dist");

    my $guard = pushd("$tempdir/$dist");

    git_init_add_commit();

    cmd_perl($minil, 'test');

    pass $dist;
}
done_testing;

