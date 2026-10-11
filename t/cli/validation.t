use strict;
use warnings;
use Test::More;
use Test::Output qw(output_from);
use lib 't/lib';
use Util;
use Minilla::Profile::ModuleBuildTiny;

my $script = File::Spec->rel2abs('script/minil');
my $lib = File::Spec->rel2abs('lib');
my $guard = pushd(tempdir(CLEANUP => 1));
Minilla::Profile::ModuleBuildTiny->new(
    author => 'hoge', dist => 'Acme-Foo', module => 'Acme::Foo',
    path => 'Acme/Foo.pm', version => '0.01',
)->generate();
write_minil_toml({ name => 'Acme-Foo', module_maker => 'ModuleBuildTiny' });
mkdir 'bin' or die "Cannot create bin: $!";
git_init_add_commit();

for my $command (qw(prepare dist release build)) {
    my $status;
    my ($stdout, $stderr) = output_from(sub {
        $status = system($^X, "-I$lib", $script, '--no-auto-install', $command);
    });
    is $status >> 8, 1, "$command exits unsuccessfully on project validation failure";
    like $stderr, qr/rename bin\/ to script\//, "$command retains the validation diagnostic";
    like $stderr, qr/Project validation failed/, "$command reports the command error";
    is $stdout, '', "$command emits no successful structured result";
}

done_testing;
