#!/usr/bin/perl -w
# this script reads usernames and corresponding passwds from
# .htaccess files and prints  them to stdout for a quick overview
# usage: script .htaccess_file
# it returns a ":" spaced list as in /etc/passwd for the .htaccess-file
# it may not be finished yet
# I once wrote it for recursive htaccess check through a big filesystem.
#
# Script by Paul Kremer 2000
# License: BSD artistic license

die "Usage: $0 htaccessfile \n" unless($ARGV[0]);

my $htaccess = $ARGV[0];
my (@cur_htaccess,@cur_users,@cur_groups,@cur_authuserfile,@cur_authgroupfile);
my ($AuthUserFile,$AuthGroupFile,$requireuser,$requiregroup);
my @finally_required_users;

&check_read_htaccess; #read the .htaccess file
&get_infos; # (require user, require group, AuthUserFile, AuthGroupFile)
#print "Required:\n";
&get_users; #put the users "require user 1 2 3 4" into a list
&get_groups;#put the groups "require group 1 2 3 4" into a list
#print "Listing:\n";
&read_AuthUserFile; # read the file with username:passwd
&read_AuthGroupFile;# read the groups
&distill; # distill all usernames that are allowed


##############################################################################
sub check_read_htaccess {
#print "Reading .htaccess-file ...\n";

open(HTACCESS,"<$htaccess") || die "Main htaccess file $htaccess not opened.\n";
while (<HTACCESS>) {
  s/^\s+//; # no leading white
  s/#.*//; #no comments
  s/\s+$//; # no trailing white
  chomp;
  push(@cur_htaccess,$_);
}
close(HTACCESS);

#print "Done.\n";
};
##############################################################################
sub get_infos {
$AuthUserFile = "";
$AuthGroupFile = "";
$requireuser = "";
$requiregroup = "";

foreach(@cur_htaccess) {
   if (/AuthUserFile/) { 
      $AuthUserFile = $_;
      $AuthUserFile =~ s/AuthUserFile//g;
      $AuthUserFile =~ s/^\s+//g; # no leadin space
      $AuthUserFile =~ s/\s+$//g; # nio trailing space
   };
   if (/AuthGroupFile/) {
      $AuthGroupFile = $_;
      $AuthGroupFile =~ s/AuthGroupFile//g;
      $AuthGroupFile =~ s/^\s+//g; # no leadin space
      $AuthGroupFile =~ s/\s+$//g; # nio trailing space
   };
   if (/require user/) {
      $requireuser = $_;
      $requireuser =~ s/require user//g;
      $requireuser =~ s/^\s+//g; # no leadin space
      $requireuser =~ s/\s+$//g; # nio trailing space
   };
   if (/require group/) {
      $requiregroup = $_;
      $requiregroup =~ s/require group//g;
      $requiregroup =~ s/^\s+//g; # no leadin space
      $requiregroup =~ s/\s+$//g; # nio trailing space 
   };
 };
};
###############################################################################
sub get_users {
#  print "  Users: ";
  $requireuser =~ s/  / /g;
  @cur_users = split(' ',$requireuser);
#  foreach(@cur_users) {    print "$_ ";  };
#  print "\n";
};

###############################################################################
sub get_groups {
#  print "  Groups: ";
  $requiregroup =~ s/  / /g;
  @cur_groups = split(' ',$requiregroup);
#  foreach(@cur_groups) {    print "$_ "; };
# print "\n";
};
###############################################################################
sub read_AuthUserFile {
if ($AuthUserFile ne "") {
 #  print "   AuthUserFile: $AuthUserFile\n";
   open(AUTHUSERFILE,"<$AuthUserFile") || &error("File $AuthUserFile not opened.\n");
   while (<AUTHUSERFILE>) {
      chomp;
      s/^\s+//g; # no leadin space
      s/#.*//; #no comments
      s/\s+$//g; # nio trailing space
      push(@cur_authuserfile,$_);
   };
   close(AUTHUSERFILE);
 #foreach (@cur_authuserfile) { print "     $_\n";};
  }
};
###############################################################################
sub read_AuthGroupFile {
#  print "   AuthGroupFile: $AuthGroupFile\n";
  if ($AuthGroupFile ne "/dev/null" && $AuthGroupFile ne "") {
     open(AUTHGROUPFILE,"<$AuthGroupFile") || &error("File $AuthGroupFile not opened.\n");;
     while (<AUTHGROUPFILE>) {
        chomp;
	s/^\s+//; # no leading white
	s/#.*//; #no comments
        s/\s+$//g; # nio trailing space
	push(@cur_authgroupfile,$_);
     };
     close(AUTHGROUPFILE);
  };
#foreach (@cur_authgroupfile) { print "     $_\n";};
};
###############################################################################
sub distill {
#print "-----------------\n";
   my @user_pass_list; # this will contain the final output as username:passwd
   foreach(@cur_users) { # put obvious users in final list
      push(@finally_required_users,$_);
   };
   foreach(@cur_groups) { #recuse allowed groups and put members into final list
     $grop = $_;
     foreach(@cur_authgroupfile) {
        if (/^$grop/) {
	   $_ = substr($_,index($_,':')+1,length($_));
           $_ =~ s/^\s+//g; # no leadin space
	   $_ =~ s/\s+$//g; # nio trailing space
	   $_ =~ s/  / /g;
	   push (@finally_required_users,split(' ',$_));
	};
     };
   };

  #may have duplicate entries for usernames, make unique list
  undef %saw;
  @finally_required_users = grep(!$saw{$_}++, @finally_required_users);

  # now get the user:passwd combo from the Authfile
   foreach(@finally_required_users) {
      $oser = $_;
      foreach(@cur_authuserfile) {
         if (/^$oser/) {
            push(@user_pass_list,$_);
         };
      };
   };
						     

#print "-----------------finally_required_users\n";
#foreach(@finally_required_users) { print "$_\n"};
#print "-----------------user_pass_list\n";
foreach(@user_pass_list) { print "$_\n"};

};




sub error {
   print STDERR "$_[0]";
};
