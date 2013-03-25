package Minilla::CLI::New;
use strict;
use warnings;
use utf8;
use File::pushd;
use File::Path qw(mkpath);

sub run {
    my ($self, @args) = @_;

    my $username;
    my $email;
    my $mb = 0;
    my $profile = 'Default';
    $self->parse_options(
        \@args,
        username => \$username,
        email    => \$email,
        'p|profile=s' => \$profile,
    );
    my $module = shift @args or $self->error("Missing module name\n");
    $username ||= `git config user.name`;
    $username =~ s/\n$//;
    $email ||= `git config user.email`;
    $email =~ s/\n$//;

    my $version = '0.01';

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

    my $profile_klass = "Minilla::Profile::${profile}";
    eval "require $profile_klass; 1;" or die $@;
    my $skelton = $profile_klass->new(
        dist    => $dist,
        path    => $path,
        author  => $username,
        module  => $module,
        version => $version,
        email   => $email,
        mb      => $mb,
        c       => $self,
    );
    {
        mkpath($dist);
        my $guard = pushd($dist);
        $skelton->generate();

        # init git repo
        $self->infof("Initializing git $module\n");
        $self->cmd('git', 'init');

        # generate project after initialize git repo
        my $project = Minilla::Project->new(
            c => $self
        );
        $project->regenerate_meta_json();
        $project->regenerate_readme_md();

        # and git add all things
        $self->cmd('git', 'add', '.');
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

=back
