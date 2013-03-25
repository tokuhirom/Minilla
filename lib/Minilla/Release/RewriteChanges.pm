package Minilla::Release::RewriteChanges;
use strict;
use warnings;
use utf8;
use Minilla::Util qw(slurp_raw spew_raw);

sub run {
    my ($self, $project, $opts) = @_;
    return if $opts->{dry_run};

    my $content = slurp_raw('Changes');
    $content =~ s!\{\{\$NEXT\}\}!
        "{{\$NEXT}}\n\n" . $project->version . " " . $project->work_dir->changes_time->strftime('%Y-%m-%dT%H:%M:%SZ')
    !e;
    spew_raw('Changes' => $content);
}


1;

