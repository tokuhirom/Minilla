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

        my $orig_file = $tar;
        $tar =~ s/\.(tar\.gz|tgz|tar.bz2|tbz|zip)$/-TRIAL.$1/
          or die "Distfile doesn't match supported archive format: $orig_file";
        $c->infof("renaming $orig_file -> $tar for TRIAL release\n");
        rename $orig_file, $tar or $c->error("Renaming $orig_file -> $tar failed: $!\n");

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

