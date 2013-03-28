use strict;
use warnings;
use utf8;
use Test::More;
use t::Util;

use Minilla;
use Minilla::Project;

my $guard = pushd(tempdir());

spew('minil.toml', <<'...');
name = "foo-bar"
...

mkpath('lib/App');
spew('lib/App/foobar.pm', <<'...');
package App::foobar;
1;
...

git_init();
git_add('.');
git_commit('-m', 'foo');

my $project = Minilla::Project->new();
is($project->main_module_path, 'lib/App/foobar.pm');

done_testing;

