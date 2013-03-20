package Minya::CLI::New;
use strict;
use warnings;
use utf8;
use Path::Tiny;
use TOML qw(to_toml);

sub run {
    my ($self, @args) = @_;

    my $username;
    my $email;
    $self->parse_options(
        \@args,
        username => \$username,
        email => \$email,
    );
    my $module = shift @args or $self->error("Missing module name\n");
    $username ||= `git config user.name`;
    $username =~ s/\n$//;
    $email ||= `git config user.email`;
    $email =~ s/\n$//;

    my $version = '0.0.1';

    unless ($username) {
        $self->error("Please set user.name in git, or use `--username` option.");
    }

    # $module = "Foo::Bar"
    # $suffix = "Bar"
    # $dist   = "Foo-Bar"
    # $path   = "Foo/Bar.pm"
    my @pkg    = split /::/, $module;
    my $suffix = $pkg[ @pkg - 1 ];
    my $dist   = join "-", @pkg;
    my $path   = join( "/", @pkg ) . ".pm";
    ( my $dir = $dist ) =~ s/^App-//;
    path(path($dist, 'lib', $path)->dirname)->mkpath;

    my $VERSION = '$VERSION';
    my $author = $username;

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
    $module_pm =~ s!(\$\w+)!$1!gee;
    path($dist, 'lib', $path)->spew($module_pm);

    path($dist, '.gitignore')->spew(<<'...');
/.build/
/_build/
/carton.lock
/.carton/
/local/
...

    path( $dist, 'minya.toml' )->spew(
        to_toml(
            +{
                main_module => "lib/$path",
                "Test::Pod"            => {},
                "Test::CPANMeta"       => {},
                "Test::MinimumVersion" => {},
            }
        )
    );

    path($dist, 'cpanfile')->spew(<<'...');
requires 'perl' => '5.008005';

on test => sub {
    requires 'Test::More' => 0.58;
};

on configure => sub {
    requires 'Module::Build' => 0.40;
};
...
    path($dist, 't')->mkpath;
    path($dist, 't', '00_compile.t')->spew(sprintf(<<'...', $module));
use strict;
use Test::More;

use_ok $_ for qw(
    %s
);

done_testing;
...

    $self->infof("Finished to create $module\n");
}

1;

