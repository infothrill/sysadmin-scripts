#!/usr/bin/env perl

# $Id: randomips.pl 347 2007-01-20 02:16:30Z pkremer $
# randomips
# v1.0 Paul Kremer

require 5.002;
use strict;
use Getopt::Std;
                           # globals
use vars qw($Me);

&init();

#############################
sub init {
   ($Me = $0) =~ s!.*/!!;   # basename of this program
   $| = 1;                  # autoflush output
}

#############################
sub usage {
   my $text = shift;
   die <<EOF
Error: $text
See $Me -h for help
EOF
};

#############################
sub help {
   print <<EOF
NAME   
       $Me - generate random IP addresses

SYNOPSIS
       $Me [-b BASENAME] [-s NUM] NUMIPS

DESCRIPTION
       $Me generates NUMIPS random IPv4 addresses and outputs them to
       STDOUT or to a number of files if you specify a basename for
       the files. The generated IP addresses are not unique and do
       not take into account any IANA rules for IP address space.

OPTIONS
       -b BASENAME
          Output will be put into files basename[.NUM] where NUM
          is the part number if you split the generated list into
          several parts. If -s is not specified, the list will be
          saved to BASENAME.

       -h 
          Displays this help

       -s NUM
          Split the list into NUM parts. The last part will be smaller
          than the preceding parts if NUMIPS modulo NUM is non-zero..

BUGS
       Email bug-reports to paul [AT] spurious [DOT] biz. Be sure to
       include the word "randomips" somewhere in the "Subject:" field.

EOF
;
exit(0);
}

#############################
sub randomIP {
   srand();
   return join('.',int (rand 254) +1,int (rand 254) +1,int (rand 254) +1,int (rand 254) +1);
};


my %args = ();
getopts("hb:s:",\%args);

my $basename = $args{'b'};
my $numfiles = $args{'s'};
my $help = $args{'h'};
$numfiles = 1 unless $numfiles;
&usage("NUM not numeric: $numfiles") unless ( $numfiles =~ m/(\d+)/);
if ($help) { &help(); };
my $numips;
if (@ARGV) {
   $numips = pop @ARGV;
   &usage("NUMIPS not numeric: $numips") unless $numips =~ m/(\d+)/;
} else {
   &usage('missing NUMIPS');
};

my $ip = 1;
my $run = 0;
my $curfile = 0;
my $curline = 0;
my $perfile = $numips/$numfiles;
if ( $perfile > int($perfile) ) { $perfile++;};
$perfile = int($perfile);

while ($run < $numips) {
   my $ipfilename;
   if ( $numfiles == 1 ) { $ipfilename = "$basename"; }
      else { $ipfilename = "$basename.$curfile"; };
   if ( $curline == 0 ) {
      if ($basename) {
         open(SPLITTED, ">$ipfilename") ||
            die("couldnt write $ipfilename: $!");
      };
   };
   if ($basename) {
      print SPLITTED &randomIP() . "\n";
   } else {
      print &randomIP() . "\n";
   };
   $curline++;
   if ( $curline == $perfile || $run+1 == $numips) {
      if ($basename) {
         close(SPLITTED) || die("couldnt close $ipfilename: $!");
         print "$ipfilename\n";
      };
      $curfile++;
      $curline = 0;
   };
   $run++;
};
