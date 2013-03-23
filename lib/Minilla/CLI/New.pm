package Minilla::CLI::New;
use strict;
use warnings;
use utf8;
use File::pushd;

use Minilla::Skeleton;


sub run {
    my ($self, @args) = @_;

    my $username;
    my $email;
    my $mb = 0;
    $self->parse_options(
        \@args,
        username => \$username,
        email    => \$email,
        mb       => \$mb, # use MB
    );
    my $module = shift @args or $self->error("Missing module name\n");
    $username ||= `git config user.name`;
    $username =~ s/\n$//;
    $email ||= `git config user.email`;
    $email =~ s/\n$//;

    my $version = 'v0.0.1';

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
        $self->error("There is $dist/\n");
    }

    my $author = $username;

    my $skelton = Minilla::Skeleton->new(
        dist    => $dist,
        path    => $path,
        author  => $username,
        module  => $module,
        version => $version,
        email   => $email,
        mb      => $mb,
        c       => $self,
    );
    $skelton->generate();

    $self->infof("Initializing git $module\n");
    {
        # init git repo
        my $guard = pushd($dist);
        $self->cmd('git', 'init');

        # generate project after initialize git repo
        my $project = Minilla::Project->new(
            c => $self->c
        );
        $project->regenerate_meta_json();
        $project->regenerate_readme_mkdn();

        # and commit all things
        $self->cmd('git', 'add', '.');
        $self->cmd('git', 'commit', '-m', 'initial import');
    }

    $self->infof("Finished to create $module\n");
}

1;
__END__

=head1 NAME

Minilla::CLI::New - Generate new module skeleton

=head1 SYNOPSIS

    # Create new app using Module::Build::Tiny(default)
    % minil new MyApp

    # Create new app using Module::Build
    % minil new MyApp --mb

=head1 DESCRIPTION

This module creates module skeleton to current directory.

=head1 OPTIONS

=over 4

=item C<--mb>

Generate skeleton using L<Module::Build>
(Default Build.PL uses L<Module::Build::Tiny>)

It's useful for XS modules.

=back
