#!/usr/bin/perl

# $Id: user2htpass 42 2003-06-26 14:45:22Z pkremer $

=head1 NAME

user2htpass - Maintain apache htpasswd file using SQL

=head1 SYNOPSIS

B<user2htpass> S<[ B<-c> I<config> ]> S<[ B<-d> I<DSN> ]> S<[ B<-f> ]> S<[ B<-h> ]> S<[ B<-o> I<file> ]> S<[ B<-p> I<pwd> ]> S<[ B<-u> I<uname> ]> S<[ B<-v> ]> S<[ B<-V> ]>

=head1 DESCRIPTION

B<user2htpass> fetches username:password information from an SQL database and
dumps them in apache htpasswd format. It converts cleartext passwords to
scrambled passwords using crypt().

=head1 OPTIONS

=over 4

=item B<-c> I<config>

Read configuration from file I<config>. See B<CONFIGURATION FILE> for syntax.

=item B<-d> I<DSN>

Use I<DSN> as data source name for DBI. Example: "dbi:mysql:database_name"

=item B<-f>

Force regeneration even if there are no usernames marked
as changed in the database, or the file 'static_htpass' is not newer than I<file>.

=item B<-h>

Display help.

=item B<-o> I<file>

If specified, the output will be saved to I<file>. If not specified, the password file will be saved to './htpass'.

=item B<-p> I<pwd>

Specify password for SQL database.

=item B<-u> I<uname>

Specify username for SQL database.

=item B<-v>

Be verbose about operation.

=item B<-V>

Display version and exit.

=back

=head1 CONFIGURATION FILE

The configuration file can be used to set some variables. The format is
variable = value. Blank lines and lines starting with # are ignored, spaces
and tabs are stripped. Options specified on the command line override the
configuration file.

Valid variables:

verbose = 0|1

force = 0|1

dsn = string

htpass = string

sql_username = string

sql_password = string

=head1 LICENSE

This program is distributed under the terms of the BSD License.

=head1 AUTHORS

Copyright (c) 2003 Paul Kremer.

=head1 CREDITS

Credits go to FSS <http://www.fss.de/> for sponsoring the development of this tool.

=head1 BUGS

It's a feature, not a bug. Please send patches in unified GNU diff
format to <pkremer[at]spurious[dot]biz>

=head1 SEE ALSO

L<perl(1)>, DBI, htpasswd

=cut

#
# TODO
#  other methods than crypt for scrambling passwords (also plaintext?)
#  chmod 644 ??!?
#
#

use DBI;
use File::Copy;
use File::Basename;
use File::Temp qw /tempfile/;
use Cwd qw/cwd/;
use Getopt::Std;
use strict;
use vars qw($Me $version);

# initialize
&init();

# command line arguments
my %args;
getopts("c:d:o:u:p:fhvV",\%args);
if ($args{'h'}) { &help(); };
if ($args{'V'}) { &version(); };

my %Prefs = &Preferences($args{'c'});  # reads prefs, if given and sets other defaults.

my ($dir,$filename);
if ($args{'o'}) {
   $dir = dirname($args{'o'});
   $filename = basename($args{'o'});
   &myverbose("chdir to $dir");
   if (-d $dir) {
      chdir $dir || die "$Me ($$): Cannot chdir to $dir\: $!";
   } else {
      die("$Me ($$): Cannot chdir to $dir\: $!");
   }
}
if (!defined $args{'o'}) {$filename = 'htpass'; };

# connect to your database
my $dbh=DBI->connect($args{'d'}, $args{'u'}, $args{'p'}) || die "$Me ($$): Cannot connect to db server $DBI::errstr";

# check if we should update or not
my $update=0;
unless ( defined $args{'f'} ) {
   # look for changes in DB
   my $sth=$dbh->prepare("SELECT ID FROM user WHERE changed=1");
   my $rv=$sth->execute;
   $sth->finish;
   if ( $rv >0 ) {
      $update = 1;
      &myverbose("Updated users in SQL database");
   }
};

if ( $update == 0 ) { &myverbose("Nothing to update"); };

# now go for it (or maybe not?)
if ( $update > 0 || defined($args{'f'}) ) { 

  my ($fh, $tempfilename);
  if (defined($args{'o'})) {
     ($fh, $tempfilename) = tempfile($filename.'XXXXXXXXX', DIR => $dir, UNLINK => 1);
  } else {
     ($fh, $tempfilename) = tempfile($filename.'XXXXXXXXX', DIR => cwd(), UNLINK => 1);
  }
  close($fh);
  &myverbose("Temp file: $tempfilename");
  &myverbose("Rewriting '$filename'");
  if (-e 'static_htpass') {
     &myverbose("static_htpass -> $filename");
     copy("static_htpass",$tempfilename) || warn("$Me ($$): Can't copy 'static_htpass' to '$tempfilename': $!");
     open($fh, ">>$tempfilename") || die("$Me ($$): Can't open '$filename' for appending: $!");
  } else {
     open($fh, ">$tempfilename") || die("$Me ($$): Can't open '$filename' for writing: $!");
  };

  #fetch domain-data
  my $sth=$dbh->prepare("SELECT username,password FROM user WHERE active=1 ORDER BY username");
  $sth->execute;
  my ($username,$clearpassword);
  while ( ( $username,$clearpassword ) = $sth->fetchrow_array ) {
    #print $fh "$username\:$clearpassword\n";
    print $fh "$username\:" . crypt($clearpassword, substr($clearpassword,0,2) ) . "\n";
  }
  $sth->finish;
  close($fh) || warn("$Me ($$): Can't close file '$tempfilename': $!");
  my $mode = 0644;
  chmod $mode, $tempfilename;
  move($tempfilename,$filename)
    || warn("$Me ($$): Can't move new '$tempfilename' to '$filename': $!");

  $dbh->do("UPDATE user SET changed=0 WHERE NOT(changed=0)")
    || warn("$Me ($$): dbh->UPDATE problem");

}

$dbh->disconnect();

exit();

#################################################
sub init {
   ($Me = $0) =~ s!.*/!!;   # basename of this program
   $| = 1;                  # autoflush output
   $version = '$Id: user2htpass 42 2003-06-26 14:45:22Z pkremer $';
}

#################################################
sub help {
system('perldoc',$Me);
exit(0);
};

#################################################
sub myverbose {
   print "$Me ($$) v: '@_'\n" if $args{'v'};
};

#################################################
sub version {
print "$Me version $version\n"; 
exit(0);
};

#################################################
sub Preferences {
   # read config file & set defaults
   my $rc = shift;
   my %Prefs;
   if (-e $rc) {
      open (RC,"<$rc") || warn("$Me ($$): error opening '$rc': $!");
      while (<RC>) {
         chomp; s/#.*//; s/^\s+//; s/\s+$//;
         next unless length;
         my ($var, $value) = split(/\s*=\s*/,$_,2);
         $Prefs{lc($var)} = $value;
      };
      close RC || warn("$Me ($$): close error on '$rc': $!");
   };
   if ( defined($Prefs{'verbose'}) ||
      int($Prefs{'verbose'}) eq $Prefs{'verbose'} && int($Prefs{'verbose'}) == 1) {
         $args{'v'} = 1;
   };
   if ( defined($Prefs{'force'}) ||
      int($Prefs{'force'}) eq $Prefs{'force'} && int($Prefs{'force'}) == 1) {
         $args{'f'} = 1;
   };
   if ( defined($Prefs{'sql_username'}) ) {
         if (! $args{'u'}) {
            $args{'u'} = $Prefs{'sql_username'};
         };
   };
   if ( defined($Prefs{'sql_password'}) ) {
         if (! $args{'p'}) {
            $args{'p'} = $Prefs{'sql_password'};
         };
   };
   if ( defined($Prefs{'dsn'}) ) {
         if (! $args{'d'}) {
            $args{'d'} = $Prefs{'dsn'};
         };
   };
   if ( defined($Prefs{'htpass'}) ) {
         if (! $args{'o'}) {
            $args{'o'} = $Prefs{'htpass'};
         };
   };
   if (defined($args{'v'})) {
      while (my ($key,$value) = each(%Prefs) ) {
         &myverbose("rc value: $key -> $value");
      };
   };
   return %Prefs;
};
