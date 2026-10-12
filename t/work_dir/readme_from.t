use strict;
use warnings;
use utf8;
use Test::More;

use lib "t/lib";
use Util;
use Archive::Tar;

use Minilla::Profile::Default;
use Minilla::Project;
use Minilla::Git;

# `release.hooks` runs after the RegenerateFiles step and before MakeDist.
# When a hook modifies the file README.md is generated from, the change has
# to be reflected in the README.md of the distribution.
subtest 'readme_from modified by release hooks' => sub {
    my $guard = pushd(tempdir(CLEANUP => 1));

    my $profile = Minilla::Profile::Default->new(
        author  => 'tokuhirom',
        dist    => 'Acme-Foo',
        path    => 'Acme/Foo.pm',
        suffix  => 'Foo',
        module  => 'Acme::Foo',
        version => '0.01',
        email   => 'tokuhirom@example.com',
    );
    $profile->generate();
    write_minil_toml({ name => 'Acme-Foo', readme_from => 'script/acme-foo' });

    mkpath('script');
    spew 'script/acme-foo', <<'...';
#!/usr/bin/env bash
: <<'=cut'

=head1 NAME

acme-foo - example script

=head1 VERSION

0.01

=cut
...

    git_init();
    git_config(qw(user.name tokuhirom));
    git_config(qw(user.email tokuhirom@example.com));
    git_add('.');
    git_commit('-m', 'initial import');

    # RegenerateFiles step
    Minilla::Project->new()->regenerate_files();
    like slurp_utf8('README.md'), qr/0\.01/,
        'README.md is generated from readme_from';
    git_add('.');
    git_commit('-m', 'regenerate files');

    # RunHooks step: a hook rewrites the file README.md is generated from
    my $script = slurp_utf8('script/acme-foo');
    $script =~ s/0\.01/0\.02/;
    spew 'script/acme-foo', $script;

    # MakeDist step
    my $dist = Minilla::Project->new()->work_dir->dist();
    my $tar = Archive::Tar->new();
    $tar->read($dist);

    like $tar->get_content('Acme-Foo-0.01/script/acme-foo'), qr/0\.02/,
        'the modification by hooks is included in the distribution';
    like $tar->get_content('Acme-Foo-0.01/README.md'), qr/0\.02/,
        'README.md in the distribution is generated from the modified file';
};

done_testing;
