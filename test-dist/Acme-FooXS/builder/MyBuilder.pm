package builder::MyBuilder;
use strict;
use warnings;
use warnings FATAL => qw(recursion);
use parent qw(Module::Build);

use File::Basename;
use Devel::PPPort;

my $xs = 'xs-src';

sub new {
    my($class, %args) = @_;

    my $so_prefix = $args{module_name};
    $so_prefix =~ s/::\w+$//;
    $so_prefix =~ s{::}{/}g;

    Devel::PPPort::WriteFile("$xs/ppport.h");

    $args{c_source} = $xs;
    $args{needs_compiler} = 1;
    $args{xs_files} = {
        map { $_ => './' . $so_prefix . '/' . basename($_) } glob("$xs/*.xs")
    };

    return $class->SUPER::new(%args);
}

1;
