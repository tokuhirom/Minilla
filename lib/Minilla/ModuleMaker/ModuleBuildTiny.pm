package Minilla::ModuleMaker::ModuleBuildTiny;
use strict;
use warnings;
use utf8;
use Data::Section::Simple qw(get_data_section);

use Moo;

no Moo;

use Minilla::Util qw(spew_raw);

sub generate {
    my ($self, $project) = @_;

    my $content = get_data_section('Build.PL');
    $content =~ s!<%\s*\$([a-z_]+)\s*%>!
        $project->$1()
    !ge;
    spew_raw('Build.PL', $content);
}

sub prereqs {
    return +{
        configure => {
            requires => {
                'Module::Build::Tiny' => 0.013,
            }
        }
    }
}

1;
__DATA__

@@ Build.PL
use 5.008005;
use Module::Build::Tiny;
Build_PL();
