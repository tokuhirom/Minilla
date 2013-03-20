package Minya::CLI::New;
use strict;
use warnings;
use utf8;
use Minya::Skelton;

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

    if (-d $dist) {
        $self->error("There is $dist.");
    }

    my $author = $username;

    Minya::Skelton->new(
        dist    => $dist,
        path    => $path,
        author  => $username,
        module  => $module,
        version => $version,
        email   => $email,
        c       => $self,
    )->generate();

    $self->infof("Finished to create $module\n");
}

1;

