use strict;
use warnings;
use utf8;
use Test::More;
use t::Util;
use Test::Requires 'Devel::CheckBin';

plan skip_all => 'Missing "tar"' unless can_run('tar');

use CPAN::Meta;

use Minilla::Profile::ModuleBuild;
use Minilla::Project;
use Minilla::Git;

subtest 'develop deps' => sub {
    my $guard = pushd(tempdir());

    my $profile = Minilla::Profile::ModuleBuild->new(
        author => 'Tokuhiro Matsuno',
        dist => 'Acme-Foo',
        path => 'Acme/Foo.pm',
        suffix => 'Foo',
        module => 'Acme::Foo',
        version => '0.01',
        email => 'tokuhirom@example.com',
    );
    $profile->generate();

    subtest 'normal' => sub {
        write_minil_toml({
            name => 'Acme-Foo',
            requires_external_bin => [ 'tar' ]
        });
        note slurp('minil.toml');

        git_init_add_commit();

        my $project = Minilla::Project->new();
        $project->regenerate_files();
        is_deeply($project->requires_external_bin, ['tar']);
        is($project->module_maker->prereqs($project)->{configure}->{requires}->{'Devel::CheckBin'}, 0);
        $project->module_maker->generate($project);
        is(system($^X, 'Build.PL'), 0);
    };

    subtest 'Failing case' => sub {
        write_minil_toml({
            name => 'Acme-Foo',
            requires_external_bin => [ 'unknown_command_name_here' ]
        });
        note slurp('minil.toml');

        git_init_add_commit();

        my $project = Minilla::Project->new();
        $project->regenerate_files();
        is_deeply($project->requires_external_bin, ['unknown_command_name_here']);
        is($project->module_maker->prereqs($project)->{configure}->{requires}->{'Devel::CheckBin'}, 0);
        $project->module_maker->generate($project);
        my $err = `$^X Build.PL 2>&1`;
        like ($err, qr/Please install 'unknown_command_name_here' seperately and try again./ms,
            "missing 'unknown_command_name_here'"
        );
    };
};

done_testing;

