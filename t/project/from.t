use strict;
use warnings;
use utf8;
use Test::More;
use t::Util;

use CPAN::Meta;

use Minilla::Profile::Default;
use Minilla::Project;
use Minilla::Git;

subtest 'abstract_from' => sub {
    my $guard = pushd(tempdir());

    my $profile = Minilla::Profile::Default->new(
        author => 'Tokuhiro Matsuno',
        dist => 'Acme-Foo',
        path => 'Acme/Foo.pm',
        suffix => 'Foo',
        module => 'Acme::Foo',
        version => '0.01',
        email => 'tokuhirom@example.com',
    );
    $profile->generate();
    mkpath('lib/Acme/');
    spew('lib/Acme/Foo.pod' => <<'...');
__END__

=encoding utf-8

=pod

=head1 NAME

Acme::Foo - Yeah!!

=head1 SYNOPSIS

    Gah

=head1 AUTHORS

author foo

...
    write_minil_toml({
        name => 'Acme-Foo',
        abstract_from => 'lib/Acme/Foo.pod',
        authors_from => 'lib/Acme/Foo.pod',
    });

    git_init_add_commit();

    my $project = Minilla::Project->new();
    is($project->abstract(), 'Yeah!!');
    is_deeply($project->authors(), ['author foo']);
};

done_testing;

