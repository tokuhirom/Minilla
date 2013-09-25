use strict;
use warnings;
use utf8;
use Test::More;
use t::Util;
use File::Temp qw(tempdir);
use File::pushd;
use Minilla::Profile::Default;
use Minilla::Project;

subtest 'Badge' => sub {
    my $guard = pushd(tempdir());

    my $profile = Minilla::Profile::Default->new(
        author => 'foo',
        dist => 'Acme-Foo',
        path => 'Acme/Foo.pm',
        suffix => 'Foo',
        module => 'Acme::Foo',
        version => '0.01',
        email => 'foo@example.com',
    );
    $profile->generate();
    git_init_add_commit();
    my $project = Minilla::Project->new();

    subtest 'Badges exist' => sub {
        my $badge_markdowns = ["[![badge1](http://example.com/badge1.png)](http://example.com)", "[![badge2](http://example.org/badge2.png)](http://example.org)"];

        write_minil_toml({
            name   => 'Acme-Foo',
            badges => $badge_markdowns,
        });
        $project->regenerate_files;

        open my $fh, '<', 'README.md';
        ok chomp (my $got = <$fh>);
        my $expected = join(' ', @$badge_markdowns);
        is $got, $expected;
    };

    subtest 'Badges do not exist' => sub {
        write_minil_toml('Acme-Foo');
        $project->regenerate_files;

        open my $fh, '<', 'README.md';
        ok chomp (my $got = <$fh>);
        is $got, "# NAME";
    };

    subtest 'Badges argument is illegal' => sub {
        write_minil_toml({
            name   => 'Acme-Foo',
            badges => 'I AM NOT ARRAY!',
        });
        $project->regenerate_files;

        open my $fh, '<', 'README.md';
        ok chomp (my $got = <$fh>);
        is $got, "# NAME";
    };
};

done_testing;
