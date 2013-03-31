use strict;
use warnings;
use utf8;
use Test::More;
use t::Util;
use File::Spec::Functions qw(catfile);

use Minilla::Profile::Default;
use Minilla::Project;
use Minilla::Git;

plan skip_all => 'Pod rewriting is temporary disabled.';

subtest 'rewrite pod' => sub {
    my $guard = pushd(tempdir());

    my $profile = Minilla::Profile::Default->new(
        author => 'tokuhirom',
        dist => 'Acme-Foo',
        path => 'Acme/Foo.pm',
        suffix => 'Foo',
        module => 'Acme::Foo',
        version => '0.01',
        email => 'tokuhirom@example.com',
    );
    $profile->generate();
    write_minil_toml('Acme-Foo');

    git_init();
    git_add('.');
    git_config(qw(user.name tokuhirom));
    git_config(qw(user.email tokuhirom@example.com));
    Minilla::Project->new()->regenerate_files();
    git_commit('-m', 'initial import');
    ok -f 'Build.PL';

    git_config(qw(user.name Foo));
    git_config(qw(user.email foo@example.com));
    git_commit('--allow-empty', '-m', 'foo');
    git_config(qw(user.name Bar));
    git_config(qw(user.email bar@example.com));
    git_commit('--allow-empty', '-m', 'bar');
    git_commit('--allow-empty', '-m', 'bar2');

    my $work_dir = Minilla::Project->new()->work_dir();
    $work_dir->build;
    ok -f catfile($work_dir->dir, 'Build.PL');
    my $pod = slurp(catfile($work_dir->dir, $work_dir->project->main_module_path));
    # note $pod;
    ok $pod =~ /=head1 CONTRIBUTORS/;
    ok $pod =~ /Bar E<lt>bar\@example\.comE<gt>/;
};

done_testing;

