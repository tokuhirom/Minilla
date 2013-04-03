package Minilla::CLI::New;
use strict;
use warnings;
use utf8;
use File::pushd;
use File::Path qw(mkpath);

use Minilla::Util qw(cmd parse_options);
use Minilla::Logger;

sub run {
    my ($self, @args) = @_;

    my $username;
    my $email;
    my $profile = 'Default';
    parse_options(
        \@args,
        'username=s' => \$username,
        'email=s'    => \$email,
        'p|profile=s' => \$profile,
    );

    my $module = shift @args or errorf("Missing module name\n");
       $module =~ s!-!::!g;

    $username ||= `git config user.name`;
    $username =~ s/\n$//;

    $email ||= `git config user.email`;
    $email =~ s/\n$//;

    my $version = '0.01';

    unless ($username) {
        errorf("Please set user.name in git, or use `--username` option.\n");
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
        errorf("There is %s/\n", $dist);
    }

    my $author = $username;

    my $profile_klass = "Minilla::Profile::${profile}";
    eval "require $profile_klass; 1;" or die $@;
    my $skelton = $profile_klass->new(
        dist    => $dist,
        path    => $path,
        author  => $username,
        suffix  => $suffix,
        module  => $module,
        version => $version,
        email   => $email,
    );
    {
        mkpath($dist);
        my $guard = pushd($dist);
        $skelton->generate();

        # init git repo
        infof("Initializing git $module\n");
        cmd('git', 'init');

        # generate project after initialize git repo
        my $project = Minilla::Project->new();
        $project->regenerate_files();

        # and git add all things
        cmd('git', 'add', '.');
    }

    infof("Finished to create $module\n");
}

1;
__END__

=head1 NAME

Minilla::CLI::New - Generate new module skeleton

=head1 SYNOPSIS

    # Create new app using Module::Build(default)
    % minil new MyApp

    # Create new app using XS
    % minil new -p XS MyApp

=head1 DESCRIPTION

This module creates module skeleton to current directory.

=head1 OPTIONS

=over 4

=back
