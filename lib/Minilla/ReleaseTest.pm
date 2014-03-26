package Minilla::ReleaseTest;
use strict;
use warnings;
use utf8;
use Data::Section::Simple qw(get_data_section);
use File::pushd;
use File::Spec::Functions qw(catfile);
use File::Path qw(mkpath);

use Minilla::Logger;
use Minilla::Util qw(spew);

sub write_release_tests {
    my ($class, $project, $dir) = @_;

    mkpath(catfile($dir, 'xt', 'minilla'));

    my $stopwords = do {
        my $append_people_into_stopwords = sub {
            my $people = shift;
            my @stopwords;
            for (@{$people || +[]}) {
                s!<.*!!; # trim e-mail address
                push @stopwords, split(/\s+/, $_);
            }
            return @stopwords;
        };

        my @stopwords;
        push @stopwords, $append_people_into_stopwords->($project->contributors);
        push @stopwords, $append_people_into_stopwords->($project->authors);
        local $Data::Dumper::Terse = 1;
        local $Data::Dumper::Useqq = 1;
        local $Data::Dumper::Purity = 1;
        local $Data::Dumper::Indent = 0;
        Data::Dumper::Dumper([map { split /\s+/, $_ } @stopwords]);
    };

    my $config = $project->config->{ReleaseTest};
    my $name = $project->dist_name;
    for my $file (qw(
        xt/minilla/minimum_version.t
        xt/minilla/cpan_meta.t
        xt/minilla/pod.t
        xt/minilla/spelling.t
    )) {
        infof("Writing release tests: %s\n", $file);

        if ($file eq 'xt/minilla/minimum_version.t' && ($config->{MinimumVersion}||'') eq 'false') {
            infof("Skipping MinimumVersion");
            next;
        }

        my $content = get_data_section($file);
        $content =~s!<<DIST>>!$name!g;
        $content =~s!<<STOPWORDS>>!$stopwords!g;
        spew(catfile($dir, $file), $content);
    }
}

sub prereqs {
    +{
        develop => {
            requires => {
                'Test::MinimumVersion::Fast' => 0.04,
                'Test::CPAN::Meta' => 0,
                'Test::Pod' => 1.41,
                'Test::Spellunker' => 'v0.2.7',
            },
        },
    };
}

1;
__DATA__

@@ xt/minilla/minimum_version.t
use Test::More;
eval "use Test::MinimumVersion::Fast 0.04";
if ($@) {
    plan skip_all => "Test::MinimumVersion::Fast required for testing perl minimum version";
}
all_minimum_version_from_metayml_ok();

@@ xt/minilla/cpan_meta.t
use Test::More;
eval "use Test::CPAN::Meta";
plan skip_all => "Test::CPAN::Meta required for testing META.yml" if $@;
plan skip_all => "There is no META.yml" unless -f "META.yml";
meta_yaml_ok();

@@ xt/minilla/pod.t
use strict;
use Test::More;
eval "use Test::Pod 1.41";
plan skip_all => "Test::Pod 1.41 required for testing POD" if $@;
all_pod_files_ok();

@@ xt/minilla/spelling.t
use strict;
use Test::More;
use File::Spec;
eval q{ use Test::Spellunker v0.2.2 };
plan skip_all => "Test::Spellunker is not installed." if $@;

plan skip_all => "no ENV[HOME]" unless $ENV{HOME};
my $spelltest_switchfile = ".spellunker.en";
plan skip_all => "no ~/$spelltest_switchfile" unless -e File::Spec->catfile($ENV{HOME}, $spelltest_switchfile);

add_stopwords('<<DIST>>');
add_stopwords(@{<<STOPWORDS>>});

all_pod_files_spelling_ok('lib');
