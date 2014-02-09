#!/usr/bin/perl -w

# $Id: dumpmz2data 25 2003-05-08 10:11:11Z pkremer $

use Getopt::Std;
use Net::DNS;
use strict;
use vars qw($Me);

&init();

my %args;
my $verbose = 0;
getopts("hv",\%args);
if ($args{'h'}) { &help(); };
if ($args{'v'}) { $verbose = 1; };
my $nameserver = "";
my $eof = 0;
if (@ARGV) {
   my $input = pop(@ARGV);
   if (scalar(@ARGV)) { # nameserver ?
      if ($ARGV[0] =~ m/\@/) {
         $nameserver = shift(@ARGV);
         $nameserver =~ s/\@//g;
      };
   };
   push(@ARGV,$input) unless ($input eq "-");
   &usage("File does not exist: $input") unless (-e $input || $input eq '-');
} else {
   &usage("no input specified");
};
if ($nameserver eq "") {
   my $res = Net::DNS::Resolver->new;
   my @nameservers = $res->nameservers;
   $nameserver = $nameservers[0];
   &verbose("You didn't specify an AXFR-server, using system default nameserver.");
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
   print <<EOF

NAME

$Me - dump multiple zones (using AXFR) to tinydns data format

SYNOPSIS

   $Me [ -h ] [ -v ] [ \@axfrserver ] [ filename... ]

DESCRIPTION
   $Me takes one or multiple zone-names as input and contacts an AXFR
   server (usually a nameserver) and initiates zone-transfers. The
   zone-date is dumped to STDOUT in the tinydns data file format.
   The zone-names are read from the list of files given on the command
   line, or from the standard input if - was specified. A
   nameserver can be specified using \@servername.

OPTIONS

   -h Display help.

   -v Be more verbose.

LICENSE
   This program is distributed under the terms of the Perl
   Artistic License.

AUTHORS
   Copyright (c) 2003 Paul Kremer.

SEE ALSO
   axfr, tcpclient 

EOF
;
exit(0);
};

######################
sub error {
   my $string = shift;
   print STDERR $string . "\n";
}
######################
sub verbose {
   if ($verbose) {
      my $string = shift;
      print STDERR $string . "\n";
   };
}
######################
sub dot2colon {
   my ($str) = @_;
   $str =~ s/\./:/;
   return $str;
};


while (!$eof) {
   my $l = <>;
   unless($l) {
      $eof = 1;
      last;
   }
   chomp($l);
   #print $l . "\n";
   my $fname = &dot2colon($l);
   my @command = ('tcpclient','-QHRl0',$nameserver,'53','axfr-get',"$l","/tmp/$fname","/tmp/$fname.tmp");
   if (system(@command) != 0)
      {
          my $exit_value  = $? >> 8;
          my $signal_num  = $? & 127;
          my $dumped_core = $? & 128;
          error("'@command' failed: $?. exit value: $exit_value. signal num: $signal_num. dumped core: $dumped_core.");
      };
   if ( -e "/tmp/$fname") {
      open(FILE,"</tmp/$fname") || die("couldn't open '/tmp/$fname': $!");
      print "################ $l ###################\n";
      while (<FILE>) {
         print;
         #unless (/^#/) {print};
      };
      close(FILE);
      unlink("/tmp/$fname") || die("couldn't unlink '/tmp/$fname': $!");;
   }
}
