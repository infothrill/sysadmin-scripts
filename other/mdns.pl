#!/usr/bin/perl -w

# $Id: mdns 17 2002-11-01 11:32:52Z pkremer $

#
# mdns is a multithreaded dns lookup tool especially tuned for
# looking up thousands of IP addresses. It outputs results asynchronously, so they
# might be in a different order than the input. It also looses NXDOMAIN etc., so it really is meant
# as a brute force lookup where individual lookups don't matter.
# It can also perform mx lookups, have combined output for MX and PTR entries etc.
#

=head1 NAME

mdns - Perform multiple DNS lookups in parallel

=head1 SYNOPSIS

B<mdns> S<[ B<-d> ]> S<[ B<-h> ]> S<[ B<-m> [ B<-r> ] [ B<-c> I<prefix> ] ]> S<[ B<-s> ]> S<[ B<-n> I<number> ]> S<[ B<-t> I<timeout> ]>
S<[ @I<server> ]> S<[ I<filename>... ]>

=head1 DESCRIPTION

B<mdns> performs multiple DNS lookups in parallel.  Names to query
are read from the list of files given on the command line, or from the
standard input if - was specified. A nameserver can be specified using
@servername.

=head1 OPTIONS

=over 4

=item B<-c>

Display resolved hostnames AND MX hosts. May only be used in conjunction
with the -m option. I<prefix> will be prepended to found MX hosts.

=item B<-d>

Turn on debugging output.

=item B<-h>

Display help.

=item B<-m>

Perform MX lookups for hostnames found and output them. No hostnames will be displayed.

=item B<-n> I<number>

Set the number of queries to have outstanding at any time (default 16).

=item B<-r>

When doing MX lookups (-m), go recursively through all domain components and check all MX records for these.

=item B<-s>

Output only the rdata string not the complete RR set.

=item B<-t> I<timeout>

Set the timeout in seconds (default 15). If no replies are received for this
amount of time, all outstanding queries will be flushed and new
names will be read from the input stream.

=back

=head1 LICENSE

This program is distributed under the terms of the Perl Artistic License.

=head1 AUTHORS

Original Copyright (c) 1997-2000 Michael Fuhr (included in the CPAN Net::DNS module as example application).
Modified version Copyright 2002 by Paul Kremer (changes include parameter for
STDIN, the help option, choosing between RR or rdata output, MX lookups, recursive domain component MX lookups, combined output and specifying a nameserver).

=head1 SEE ALSO

L<perl(1)>, L<axfr>, L<check_soa>, L<check_zone>, L<mx>, L<perldig>,
L<Net::DNS>

=cut

use Net::DNS;
use IO::Select;
use Getopt::Std;
use strict;
use vars qw($Me);

$| = 1;

&init();

my %args;
$args{'n'} = 16;	# number of requests to have outstanding at any time
$args{'t'} = 15;	# timeout (seconds)

getopts("c:mrshdn:t:",\%args);

if ($args{'h'}) { &help(); };
if (defined($args{'r'}) && !defined($args{'m'}) ) { &usage('ambigous options'); };
if (defined($args{'c'}) && !defined($args{'m'}) ) { &usage('ambigous options'); };
my $res = Net::DNS::Resolver->new;
my $sel = IO::Select->new;
my $nameserver;
my $eof = 0;
if (@ARGV) {
   my $input = pop(@ARGV);
   if (scalar(@ARGV)) { # nameserver ?
      if ($ARGV[0] =~ m/\@/) {
         $nameserver = shift(@ARGV);
         $nameserver =~ s/\@//g;
         $res->nameservers($nameserver);
      };
   };
   push(@ARGV,$input) unless ($input eq "-");
   &usage("File does not exist: $input") unless (-e $input || $input eq '-');
} else {
   &usage("no input specified");
};

#############################
sub init {
   ($Me = $0) =~ s!.*/!!;   # basename of this program
    $| = 1;                  # autoflush output
}

#############################
sub usage{
   my $text = shift;
   die <<EOF
Error: $text
See $Me -h for help
EOF
};

#############################
sub help{
system('perldoc',$Me);
exit(0);
};

while (1) {
	my $name;
	my $sock;

	#----------------------------------------------------------------------
	# Read names until we've filled our quota of outstanding requests.
	#----------------------------------------------------------------------

	while (!$eof && $sel->count < $args{'n'}) {
		print "DEBUG: reading..." if defined $args{'d'};
		$name = <>;
		unless ($name) {
			print "EOF.\n" if defined $args{'d'};
			$eof = 1;
			last;
		}
		chomp $name;
		$sock = $res->bgsend($name);
		$sel->add($sock);
		print "name = $name, outstanding = ", $sel->count, "\n"
			if defined $args{'d'};
	}

	#----------------------------------------------------------------------
	# Wait for any replies.  Remove any replies from the outstanding pool.
	#----------------------------------------------------------------------

	my @ready;
	my $timed_out = 1;

	print "DEBUG: waiting for replies\n" if defined $args{'d'};

	for (@ready = $sel->can_read($args{'t'});
	     @ready;
	     @ready = $sel->can_read(0)) {

		$timed_out = 0;

		print "DEBUG: replies received: ", scalar @ready, "\n"
			if defined $args{'d'};

		foreach $sock (@ready) {
			print "DEBUG: handling a reply\n" if defined $args{'d'};
			$sel->remove($sock);
			my $ans = $res->bgread($sock);
			next unless $ans;
			my $rr;
			foreach $rr ($ans->answer) {
            if (defined($args{'c'}) || !defined($args{'m'})) {
               if (defined($args{'s'})) {
                  print $rr->rdatastr . "\n";
               } else {
                  $rr->print;
               };
            };
            if (defined($args{'m'})) {
               if (defined($args{'r'})) {
                  &test_mx( $rr->rdatastr );
               } else {
                  &mxlookup( $rr->rdatastr );
               };
            };
			}
		}
	}

	#----------------------------------------------------------------------
	# If we timed out waiting for replies, remove all entries from the
	# outstanding pool.
	#----------------------------------------------------------------------

	if ($timed_out) {
		print "DEBUG: timeout: clearing the outstanding pool.\n"
			if defined $args{'d'};
		my $sock;
		foreach $sock ($sel->handles) {
			$sel->remove($sock);
		}
	}

	print "DEBUG: outstanding = ", $sel->count, ", eof = $eof\n"
		if defined $args{'d'};

	#----------------------------------------------------------------------
	# We're done if there are no outstanding queries and we've read EOF.
	#----------------------------------------------------------------------

	last if ($sel->count == 0) && $eof;
}

sub mxlookup {
   my $domain = shift;
   my @result; # list containing hostnames of MX's
   my @mx = mx($res,$domain);
   if (@mx) {
      foreach my $rr (@mx) {
         if (defined($args{'c'})) { print $args{'c'}; };
         print $rr->exchange . "\n";
         #push(@result,$rr->exchange);
      };
   };
   return @result;
};

sub test_mx {
   my ($remote) = @_;
   my @result;
   my @domain_components = split /\./, $remote;
   while (@domain_components > 2) {
      my @thissubdomainmx = &mxlookup(join('.',@domain_components));
      push(@result,@thissubdomainmx);
      shift(@domain_components);
   };
   return @result;
};

