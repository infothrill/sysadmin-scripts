#!/usr/bin/env perl

# Drop-in replacement for Apache's logresolve program [1] which sometimes
# fucks up log by splitting it and thus creating new garbage lines.
# - reads from stdin and writes to stdout
# - no options
#
# [1] http://httpd.apache.org/docs/2.0/programs/logresolve.html

use warnings;
use strict;
use Net::DNS;
use IO::Select;

$| = 1; # disable buffering

my $res = Net::DNS::Resolver->new;

our %host;

while(<>) {
    my $line = $_;
    my ( $ip, $rest ) = $line =~ /^(\S+)+(.*)/;

    if ( !( defined $host{$ip} ) ) {
        if ( $ip =~ /^\d+(?:\.\d+){0,3}$/ ) {
            $host{$ip} = &lookup($ip, $res);
        }
        else { $host{$ip} = $ip; }
    }
    print $host{$ip}, $rest, "\n";
}

sub lookup {
    my $ip_address = shift;
    my $res = shift;
    my $result;
    my $bgsock = $res->bgsend( $ip_address );
    my $sel = new IO::Select($bgsock);
    my @ready = $sel->can_read(5); # 5 seconds
    if (@ready) {
        foreach my $sock (@ready) {
            if ($sock == $bgsock) {
                my $packet = $res->bgread($bgsock);
                if ($packet) {
                    foreach my $rr ($packet->answer) {
                        my $hostname = $rr->rdatastr;
                        $hostname =~ s/\.$//g;
                        $result = $hostname;
                    }
                }
                else { 
                    $result = $ip_address;
                }
                $bgsock = undef;
            }
            $sel->remove($sock);
            $sock = undef;
        }
    }
    else {
        $result = $ip_address;
    }
    $result = $ip_address unless defined $result;
    $result = $ip_address if $result eq "";
    $result = $ip_address if $result eq "."; # some people do this!
    return $result;
}
