#!/usr/bin/perl -p

# hextoip.pl is a generic reformatter for djbware logs.
#            It translates IP addresses and ports numbers from
#            Hex to numeric format.  It is simply a rehashing
#            of Faried Nawaz's dnscache log formatter.

# For the best results, pipe your logs through tai64nlocal, then this.

if (/[a-f0-9]{8}/) {
	s/\b([a-f0-9]{8})\b/join(".", unpack("C*", pack("H8", $1)))/eg;
}

if (/[a-f0-9]{4}/) {
	s/([a-f0-9]{4}):([a-f0-9]{4})/decypher($1,$2)/e;
}

sub decypher {
	my ($port, $query) = @_;
	$ret = hex($port).":".hex($query);
	return $ret;
}

