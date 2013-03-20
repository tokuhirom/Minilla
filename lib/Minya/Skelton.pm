package Minya::Skelton;
use strict;
use warnings;
use utf8;
use File::Spec::Functions qw(catfile);
use File::Path qw(mkpath);
use File::Basename qw(dirname);
use Time::Piece;
use TOML qw(to_toml);
use CPAN::Meta;

use Minya::License;
use Minya::Util;

use Moo;

has [qw(c dist author path module version email)] => (
    is       => 'ro',
    required => 1,
);

no Moo;

sub generate {
    my $self = shift;

    my $module_pm = <<'...';
package $module;
use strict;
use warnings;
our $VERSION = '$version';

1;
__END__

=head1 NAME

$module - It's new $module

=head1 SYNOPSIS
    
    use $module;

=head1 DESCRIPTION

$module is ...

=head1 LICENSE

Copyright (C) $author

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

$author $<lt> $email E<gt>

...
    $module_pm =~ s!\$(\w+)!$1 eq 'VERSION' ? '$VERSION' : $self->$1!ge;
    $self->write_file('lib', $self->path, $module_pm);

    $self->write_file('.gitignore', <<'...');
/.build/
/_build/
/carton.lock
/.carton/
/local/
...

    my $date = gmtime->strftime('%Y-%m-%dT%H:%M:%SZ');
    $self->write_file('Changes', <<"...");
Revision history for Perl extension @{[ $self->dist ]}

0.0.1 $date

    - original version
...

    $self->write_file('minya.toml' => 
        to_toml(
            +{
                name => $self->module
            }
        )
    );

    $self->write_file('cpanfile', <<'...');
requires 'perl' => '5.008005';

on test => sub {
    requires 'Test::More' => 0.58;
};

on configure => sub {
    requires 'Module::Build::Tiny';
};
...

    $self->write_file('t', '00_compile.t', sprintf(<<'...', $self->module));
use strict;
use Test::More;

use_ok $_ for qw(
    %s
);

done_testing;
...

    # Generate Build.PL and META.json for installable git repo.
    $self->write_file('Build.PL', <<'...');
use Module::Build::Tiny ;
Build_PL();
...

    my $data = {
        "meta-spec" => {
            "version" => "2",
            "url"     => "http://search.cpan.org/perldoc?CPAN::Meta::Spec"
        },
        abstract => "blah blah blah",
        author => $self->author,
        dynamic_config => 0,
        license => 'perl_5',
        version => $self->version,
        name => $self->dist,
        prereqs => Module::CPANfile->load('cpanfile')->prereq_specs,
        generated_by => "Minya/$Minya::VERSION",
        release_status => 'unstable',
    };
    CPAN::Meta->new($data)->save(catfile($self->dist, 'META.json'), {version => '2.0'});

    $self->write_file('LICENSE', Minya::License->perl_5($self->author, $self->email));
}

sub write_file {
    my $self = shift;
    my $content = pop;

    my $path = catfile($self->dist, @_);
    $self->c->infof("Writing %s\n", $path);
    mkpath(dirname($path));
    spew($path, $content);
}

1;

