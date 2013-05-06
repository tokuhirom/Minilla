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
script_files = ['bin/foo', 'script/*']
...

mkpath('lib/App');
spew('lib/App/foobar.pm', <<'...');
package App::foobar;
1;
...

git_init_add_commit();
my $project = Minilla::Project->new();

is $project->script_files, "glob('bin/foo'), glob('script/*')";

done_testing;
