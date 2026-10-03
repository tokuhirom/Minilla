package Minilla::Changes;
use strict;
use warnings;
use utf8;

sub prepared_release {
    my ($content, $version) = @_;

    return unless $content =~ /^\{\{\$NEXT\}\}\h*\R/m;

    my $next_start = $-[0];
    my $next_end = $+[0];
    my $after_next = substr($content, $next_end);
    return unless $after_next =~ /^\Q$version\E(?=\h|\R|\z)/m;

    my $version_start = $next_end + $-[0];
    my $pending = substr($content, $next_end, $version_start - $next_end);

    return {
        next_start => $next_start,
        version_start => $version_start,
        has_pending_changes => $pending =~ /\S/ ? 1 : 0,
    };
}

1;
