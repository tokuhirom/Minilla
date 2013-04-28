use strict;
use warnings;
use utf8;
use Test::More;
use t::Util;

use File::Spec;
use File::Spec::Functions qw(catdir);
use File::Path;
use File::Basename;
use File::Copy::Recursive qw(rcopy);

use Minilla::Git;

my $minil = File::Spec->rel2abs('script/minil');

for my $datfile (map { File::Spec->rel2abs($_) } 't/dist/Acme-FooXS.dat') {
    basename($datfile) =~ m{^(.*)\.dat$} or die;
    my $distname = $1;
    subtest $datfile => sub {
        note $distname;
        my $tempdir = tempdir(CLEANUP => 1);
        my $distdir = catdir($tempdir, $distname);
        mkpath($distdir);
        my $guard = pushd($distdir);
        extract_archive($datfile);
        git_init_add_commit();

        system 'cat lib/Acme/FooXS.pm';
        cmd_perl($minil, 'test');

        pass $distname;
    };
}

sub extract_archive {
    unpack_archive(parse_archive(shift));
}

sub parse_archive {
    my $archive = shift;
    my $fname;
    my %result;
    open my $fh, '<', $archive or die;
    while (<$fh>) {
        if (/^==> (.+) <==$/) {
            $fname = $1;
        } else {
            $result{$fname} .= $_;
        }
    }
    return %result;
}

sub unpack_archive {
    my %filemap = @_;
    for my $filename (keys %filemap) {
        mkpath(dirname($filename));
        note "Writing $filename";
        spew($filename, $filemap{$filename});
    }
}

done_testing;

