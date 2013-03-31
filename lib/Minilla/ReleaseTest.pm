package Minilla::ReleaseTest;
use strict;
use warnings;
use utf8;
use Data::Section::Simple qw(get_data_section);
use File::pushd;
use Path::Tiny;
use File::Spec::Functions qw(catfile);
use File::Path qw(mkpath);

use Minilla::Logger;
use Minilla::Util qw(spew);

sub write_release_tests {
    my ($class, $project, $dir) = @_;

    mkpath(catfile($dir, 'xt'));

    my $stopwords = do {
        my @stopwords;
        for (@{$project->contributors || +[]}) {
            s!<.*!!; # trim e-mail address
            push @stopwords, split(/\s+/, $_);
        }
        join(' ', @stopwords);
    };
    my $name = $project->dist_name;
    for my $file (qw(
        xt/minimum_version.t
        xt/cpan_meta.t
        xt/pod.t
        xt/spelling.t
    )) {
        infof("Writing release tests: %s\n", $file);
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
                'Test::MinimumVersion' => 0.101080,
                'Test::CPAN::Meta' => 0,
                'Test::Pod' => 1.41,
                'Test::Spelling' => 0,
                'Pod::Wordlist::hanekomu' => 0,
            },
        },
    };
}

1;
__DATA__

@@ xt/minimum_version.t
use Test::More;
eval "use Test::MinimumVersion 0.101080";
plan skip_all => "Test::MinimumVersion required for testing perl minimum version" if $@;
all_minimum_version_from_metayml_ok();

@@ xt/cpan_meta.t
use Test::More;
eval "use Test::CPAN::Meta";
plan skip_all => "Test::CPAN::Meta required for testing META.yml" if $@;
plan skip_all => "There is no META.yml" unless -f "META.yml";
meta_yaml_ok();

@@ xt/pod.t
use strict;
use Test::More;
eval "use Test::Pod 1.41";
plan skip_all => "Test::Pod 1.41 required for testing POD" if $@;
all_pod_files_ok();

@@ xt/spelling.t
use strict;
use Test::More;
use File::Spec;
eval q{ use Test::Spelling };
plan skip_all => "Test::Spelling is not installed." if $@;
eval q{ use Pod::Wordlist::hanekomu };
plan skip_all => "Pod::Wordlist::hanekomu is not installed." if $@;

plan skip_all => "no ENV[HOME]" unless $ENV{HOME};
plan skip_all => "no ~/.aspell.en.pws" unless -e File::Spec->catfile($ENV{HOME}, '.aspell.en.pws');

add_stopwords('<<DIST>>');
add_stopwords(qw(<<STOPWORDS>>));

$ENV{LANG} = 'C';
my $has_aspell;
foreach my $path (split(/:/, $ENV{PATH})) {
    -x "$path/aspell" and $has_aspell++, last;
}
plan skip_all => "no aspell" unless $has_aspell;
plan skip_all => "no english dict for aspell" unless `aspell dump dicts` =~ /en/;

set_spell_cmd('aspell list -l en');
all_pod_files_spelling_ok('lib');
