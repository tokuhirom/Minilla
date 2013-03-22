package Minilla::CPANMeta;
use strict;
use warnings;
use utf8;
use CPAN::Meta;
use File::pushd;
use Module::Metadata;
use File::Spec;

use Moo;

has [qw(config prereq_specs base_dir)] => (
    is => 'ro',
    required => 1,
);

no Moo;

sub generate {
    my ($self, $release_status) = @_;
    $release_status ||= 'stable';

    my $dat = {
        "meta-spec" => {
            "version" => "2",
            "url"     => "http://search.cpan.org/perldoc?CPAN::Meta::Spec"
        },
        license        => $self->config->license_meta2,
        abstract       => $self->config->abstract,
        author         => [ $self->config->author ],
        dynamic_config => 0,
        version        => $self->config->version,
        name           => $self->config->dist_name,
        prereqs        => $self->prereq_specs,
        generated_by   => "Minilla/$Minilla::VERSION",
        release_status => $release_status || 'stable',
    };
    if ($release_status ne 'unstable') {
        $dat->{provides} = Module::Metadata->provides(
            dir     => File::Spec->catdir($self->base_dir, 'lib'),
            version => 2
        );
    }

    {
        my $guard = pushd($self->base_dir);
        if ( `git remote show -n origin` =~ /URL: (.*)$/m && $1 ne 'origin' ) {
            # XXX Make it public clone URL, but this only works with github
            my $git_url = $1;
            $git_url =~ s![\w\-]+\@([^:]+):!git://$1/!;
            if ($git_url =~ /github\.com/) {
                my $http_url = $git_url;
                $http_url =~ s![\w\-]+\@([^:]+):!https://$1/!;
                $http_url =~ s!\.git$!/tree!;
                $dat->{resources}->{repository} = +{
                    url => $git_url,
                };
                $dat->{resources}->{homepage} = $self->config->homepage || $http_url;
            } else {
                # normal repository
                $dat->{resources}->{repository} = +{
                    url => $git_url,
                };
            }
        }
    }

    # TODO: provides

    my $meta = CPAN::Meta->new($dat);
    return $meta;
}

1;

