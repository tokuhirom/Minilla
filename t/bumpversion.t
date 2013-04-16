use strict;
use warnings;
use utf8;
use Test::More;
use t::Util;

use Dist::BumpVersion::Perl;
use File::Temp qw(tempdir);
use Module::Metadata;

my $tmpdir = tempdir(CLEANUP => 1);
my $tmpfile = "$tmpdir/Foo.pm";
open my $fh, '>', $tmpfile or die $!;
print {$fh} q{
package Foo;
our $VERSION="v0.0.1";
1;
};
close $fh;


# check
{
    my $meta = Module::Metadata->new_from_file($tmpfile);
    is($meta->version('Foo'), 'v0.0.1');
}

# bump
{
    my $bump = Dist::BumpVersion::Perl->load($tmpfile);
    ok($bump);
    $bump->set_version('v0.0.2');
}

# test.
{
    my $meta = Module::Metadata->new_from_file($tmpfile);
    is($meta->version('Foo'), 'v0.0.2');
}

done_testing;

