#!/usr/bin/perl
# this scripts can be used to downcase all files in a directory
# by saying;
#
# dwncase.pl *
# 
# Paul Kremer 2000.
# 
foreach (@ARGV) {
          if (not -e lc($_)) {
          print "$_ --> ",  lc($_),"\n";}
          rename ($_, lc($_));
       };
