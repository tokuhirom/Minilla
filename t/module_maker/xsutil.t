use strict;
use warnings;
use utf8;
use Test::More;
use t::Util;

use Minilla::Profile::ModuleBuild;
use Minilla::Project;

test(
    {},
    sub {
        my $buildpl = slurp('Build.PL');
        like( $buildpl, qr!use Module::Build::XSUtil;! );
        like( $buildpl, qr!needs_compiler_c99\s+=>\s+0! );
        like( $buildpl, qr!needs_compiler_cpp\s+=>\s+0! );
        like( $buildpl, qr!generate_ppport_h\s+=>\s+\'0\'! );
        like( $buildpl, qr!generate_xshelper_h\s+=>\s+\'0\'! );
        like( $buildpl, qr!cc_warnings\s+=>\s+0! );
    }
);

test(
    {   needs_compiler_c99  => 1,
        needs_compiler_cpp  => 1,
        generate_ppport_h   => 1,
        generate_xshelper_h => 1,
        cc_warnings         => 1,
    },
    sub {
        my $buildpl = slurp('Build.PL');
        like( $buildpl, qr!use Module::Build::XSUtil;! );
        like( $buildpl, qr!needs_compiler_c99\s+=>\s+1! );
        like( $buildpl, qr!needs_compiler_cpp\s+=>\s+1! );
        like( $buildpl, qr!generate_ppport_h\s+=>\s+\'1\'! );
        like( $buildpl, qr!generate_xshelper_h\s+=>\s+\'1\'! );
        like( $buildpl, qr!cc_warnings\s+=>\s+1! );
    }
);

test(
    {   
        generate_ppport_h   => 'lib/ppport.h',
        generate_xshelper_h => 'lib/xshelper.h',
    },
    sub {
        my $buildpl = slurp('Build.PL');
        like( $buildpl, qr!use Module::Build::XSUtil;! );
        like( $buildpl, qr!generate_ppport_h\s+=>\s+\'lib/ppport\.h\'! );
        like( $buildpl, qr!generate_xshelper_h\s+=>\s+\'lib/xshelper\.h\'! );
    }
);

done_testing;

sub test {
    my $xsutil = shift;
    my $code   = shift;

    my $guard = pushd( tempdir() );

    Minilla::Profile::ModuleBuild->new(
        author  => 'hoge',
        dist    => 'Acme-Foo',
        module  => 'Acme::Foo',
        path    => 'Acme/Foo.pm',
        version => '0.01',
    )->generate();

    spew( 'MANIFEST', <<'...');
    Build.PL
    lib/Acme/Foo.pm
...
    write_minil_toml(
        {   name   => 'Acme-Foo',
            XSUtil => $xsutil,
        }
    );
    git_init_add_commit();
    Minilla::Project->new()->regenerate_files();
    git_init_add_commit();
    $code->();
}
