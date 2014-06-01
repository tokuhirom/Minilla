use strict;
use warnings;
use utf8;
use Test::More;
use t::Util;

use Module::BumpVersion;
use File::Temp qw(tempdir);
use Module::Metadata;

my $tmpdir = tempdir(CLEANUP => 1);

subtest 'normal' => sub {
    my $tmpfile = "$tmpdir/Foo.pm";
    open my $fh, '>', $tmpfile or die $!;
    print {$fh} q{
package Foo;
our $VERSION="v0.0.1";
1;
};
    close $fh;
    test($tmpfile);
};

subtest 'gah' => sub {
    my $tmpfile = "$tmpdir/Bar.pm";
    open my $fh, '>', $tmpfile or die $!;
    print {$fh} q{
package Foo;
use version; our $VERSION = version->declare("v0.0.1");
1;
};
    close $fh;
    test($tmpfile);
};

subtest 'no bumpversion' => sub {
    my $tmpfile = "$tmpdir/Baz.pm";
    open my $fh, '>', $tmpfile or die $!;
    print {$fh} q{
package Baz;
our $VERSION="v0.0.1"; # No BumpVersion
1;
};
    close $fh;

    # check
    {
        my $meta = Module::Metadata->new_from_file($tmpfile);
        is($meta->version('Baz'), 'v0.0.1');
    }

    # bump
    {
        my $bump = Module::BumpVersion->load($tmpfile);
        ok($bump);
        ok(!$bump->find_version);
        $bump->set_version('v0.0.2');
    }

    # test.
    {
        my $meta = Module::Metadata->new_from_file($tmpfile);
        is($meta->version('Baz'), 'v0.0.1');
    }
};


done_testing;

sub test {
    my $tmpfile = shift;

    # check
    {
        my $meta = Module::Metadata->new_from_file($tmpfile);
        is($meta->version('Foo'), 'v0.0.1');
    }

    # bump
    {
        my $bump = Module::BumpVersion->load($tmpfile);
        ok($bump);
        is($bump->find_version, 'v0.0.1');
        $bump->set_version('v0.0.2');
    }

    # test.
    {
        my $meta = Module::Metadata->new_from_file($tmpfile);
        is($meta->version('Foo'), 'v0.0.2');
    }
}
