use strict;
use warnings;
use utf8;
use Test::More;
use File::Temp qw(tempdir);
use File::pushd;

use Minilla::Release::CheckChanges;
use Minilla::Release::RewriteChanges;
use Minilla::Util qw(slurp_raw spew_raw);

{
    package Local::Project;

    sub new {
        my ($class, $version) = @_;
        bless { version => $version }, $class;
    }

    sub version { shift->{version} }
}

subtest 'prepared Changes passes release checks and remains unchanged' => sub {
    my $guard = pushd(tempdir(CLEANUP => 1));
    my $project = Local::Project->new('v1.2.3');
    my $content = <<'EOF';
Revision history for Perl extension Hoge

{{$NEXT}}

v1.2.3 2025-12-17T15:08:28Z
    - Hogehoge
EOF
    spew_raw('Changes', $content);

    Minilla::Release::CheckChanges->run($project, {});
    Minilla::Release::RewriteChanges->run($project, {});

    is slurp_raw('Changes'), $content,
        'release does not duplicate the prepared version or change its timestamp';
};

done_testing;
