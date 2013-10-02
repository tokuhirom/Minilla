use strict;
use warnings;
use utf8;
use Test::More;

use t::Util;
use File::Spec::Functions qw(catfile);

use Minilla::Profile::Default;
use Minilla::Project;
use Minilla::Git;

subtest 'Contributors are included in stopwords' => sub {
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

    git_config(qw(user.name Foo));
    git_config(qw(user.email foo@example.com));
    git_commit('--allow-empty', '-m', 'foo');
    git_config(qw(user.name Bar));
    git_config(qw(user.email bar@example.com));
    git_commit('--allow-empty', '-m', 'bar');

    my $work_dir = Minilla::Project->new()->work_dir();
    $work_dir->build;
    my $spelling_test_file = catfile($work_dir->project->work_dir->dir, 'xt', 'minilla', 'spelling.t');

    ok -f $spelling_test_file;
    my $spelling  = slurp($spelling_test_file);
    my ($stopwords) = $spelling =~ /add_stopwords\(\@(.*)\);/;

    like $stopwords, qr(tokuhirom) or diag $spelling;
    like $stopwords, qr(Foo) or diag $stopwords;
    like $stopwords, qr(Bar);
};
done_testing;
