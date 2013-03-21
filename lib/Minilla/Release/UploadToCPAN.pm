package Minilla::Release::UploadToCPAN;
use strict;
use warnings;
use utf8;

sub run {
    my ($self, $c) = @_;

    my $work_dir = Minilla::WorkDir->instance($c);
    my $tar = $work_dir->dist;

    if ($c->dry_run) {
        $c->infof("Dry run\n");
    } else {
        $c->infof("Upload to CPAN\n");
        my $config = CPAN::Uploader->read_config_file();
        my $uploader = CPAN::Uploader->new(+{
            tar => $tar,
            %$config
        });
        $uploader->upload_file($tar);
    }

    unlink($tar) unless $c->debug;
}

1;

