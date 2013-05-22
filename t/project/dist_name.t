use strict;
use warnings;
use utf8;
use Test::More;
use File::Basename qw(basename);
use t::Util;

use Minilla;
use Minilla::Project;

subtest 'Single hyphen delimiter' => sub {
    my $guard = pushd( tempdir( 'App-foobar-XXXX', CLEANUP => 1 ) );
    my $delimiter = '-';
    test_dist_name( $guard, $delimiter );
};

subtest 'Double hyphen delimiter' => sub {
    my $guard = pushd( tempdir( 'App--foobar--XXXX', CLEANUP => 1 ) );
    my $delimiter = '--';
    test_dist_name( $guard, $delimiter );
};

subtest 'Single hyphen delimiter with "p5-" prefix' => sub {
    my $guard = pushd( tempdir( 'p5-App-foobar-XXXX', CLEANUP => 1 ) );
    my $delimiter = '-';
    test_dist_name( $guard, $delimiter );
};

subtest 'Double hyphen delimiter with "p5-" prefix' => sub {
    my $guard = pushd( tempdir( 'p5-App--foobar--XXXX', CLEANUP => 1 ) );
    my $delimiter = '--';
    test_dist_name( $guard, $delimiter );
};

done_testing;

sub test_dist_name {
    my ($guard, $delimiter) = @_;

    my $base_name = basename( $guard->{_pushd} );
    my ($module_name) = $base_name =~ /$delimiter([^-]*)$/;

    mkpath('lib/App/foobar');
    spew("lib/App/foobar/$module_name.pm", <<"...");
package App::foobar::$module_name;
1;
...

    git_init();
    git_add('.');
    git_commit('-m', 'foo');

    my $project = Minilla::Project->new();
    is($project->dist_name, "App-foobar-$module_name");
}

