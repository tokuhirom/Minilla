package Minya::CLI::Release;
use strict;
use warnings;
use utf8;
use Path::Tiny;
use ExtUtils::MakeMaker qw(prompt);
use CPAN::Uploader;

use Minya::Util qw(edit_file);
use Minya::WorkDir;

sub run {
    my ($self, @args) = @_;

    my $test = 1;
    $self->parse_options(
        \@args,
        'test!' => \$test,
    );

    # perl-revision command is included in Perl::Version.
    $self->cmd('perl-reversion', '-bump');

    my $version = $self->config->metadata->version;

    until (path('Changes')->slurp =~ /^$version/m) {
        if (prompt("There is no $version, do you want to edit changes file?", 'y') =~ /y/i) {
            edit_file('Changes');
        } else {
            $self->error("Giving up!");
        }
    }

    my $tar = Minya::WorkDir->make_tar_ball($self, $test);

    $self->infof("Upload to CPAN\n");
    my $config = CPAN::Uploader->read_config_file();
    my $uploader = CPAN::Uploader->new(+{
        tar => $tar,
        %$config
    });
    $uploader->upload_file($tar);

    path($tar)->remove unless $self->debug;

    # TODO commit
    # TODO tag
    # TODO push tags
}

1;

