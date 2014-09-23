#!/usr/bin/perl
my $ID = q$Id: squirrel_datafiles_cleanup.pl 472 2005-10-06 22:05:51Z pkremer $;
#
# squirrel_datafiles_cleanup -- clean old squirrelmail data files for orphaned
# accounts and check file permissions. This works only with vpopmail, a server
# side mail hosting system on top of Qmail.
#
# Written by Paul Kremer <pkremer [at] spurious [dot] biz>
# Copyright 2004, Paul Kremer.
#
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.

##############################################################################
# Site configuration
##############################################################################

use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use File::Find;
use File::Basename;

use vars qw ( $goners $delcount $validemails $cachehits  $files $exclude_files $ignorecount $unknownfilescount);

# Clean up $0 for error reporting.
my $fullpath = $0;
$0 =~ s%^.*/%%;

# command line arguments
my ($help, $version, $configfile, $listfiles, $summary) = (undef, undef, undef, undef, undef);
Getopt::Long::config ('bundling', 'no_ignore_case');
GetOptions ('help|h' => \$help, 'version|v' => \$version, 'config|c=s' => \$configfile, 'listfiles|l' => \$listfiles, 'summary|s' => \$summary) or exit 1;
if ($help) {
    print "Feeding myself to perldoc, please wait....\n";
    exec ('perldoc', '-t', $fullpath) or die "$0: can't fork: $!\n";
} elsif ($version) {
    my $version = join (' ', (split (' ', $ID))[1..3]);
    $version =~ s/,v\b//;
    $version =~ s/(\S+)$/($1)/;
    print $version, "\n";
    exit 0;
}
unless ( $configfile ) {
	$configfile = '/etc/squirrel.conf';
}

my $prefs = readPreferences($configfile);

die "$0: config key 'squirrelmail_datadir' missing\n" unless defined $prefs->{squirrelmail_datadir};
die "$0: config key 'vpopmail_dir' missing\n" unless defined $prefs->{vpopmail_dir};

unless (-d $prefs->{vpopmail_dir}) {
	die "$0: vpopmail_dir '$prefs->{vpopmail_dir}' problem: not a directory!\n";
}
if (! -e "$prefs->{vpopmail_dir}/bin/vuserinfo" ) {
	die "$0: $prefs->{vpopmail_dir}/bin/vuserinfo could not be found\n";
};
if (! -d $prefs->{squirrelmail_datadir} ) {
	die "$0: $prefs->{squirrelmail_datadir} could not be found or is not a directory\n";
};
if (defined $prefs->{squirrelmail_datadir_exclude_files} ) {
	%{$exclude_files} = map { $_ => $_ } split / /, $prefs->{squirrelmail_datadir_exclude_files};
};

#####################################################################


#####################################################################
sub readPreferences {
	my $rc = shift || die "$0: no config file specified\n";

	my $result = undef;
	if (-f $rc) {
		open (RC,"<$rc") || warn("$0: error opening '$rc': $!\n");
		while (<RC>) {
			my $line = $_;
			next if $line =~ /^\s*[#%;]/ or $line =~ /^\s*\r*$/;
			if ($line =~ m/^\s*([^\s=]+)\s*=\s*(.*?)\s*$/) {
				my ($key, $value) = ($1, $2);
				die "$0: duplicate cfg value: $key\n" if exists $result->{$key};
				$result->{$key} = $value;
			} else {
				die "TODO '$line' in '".$rc."'";
			}
		}
	} else {
		die "$0: config file $rc not found\n";
	}
	return $result;
};

#####################################################################
sub isValidEmail {
	my $email = shift || die "no email address specified\n";

	my @cmd = ('nice','-n','20', '"'.$prefs->{vpopmail_dir}.'/bin/vuserinfo"', $email);
	my $cmdstr = join(' ',@cmd);
	#print "\n\n" . $cmdstr . "\n\n";
	my $out = `$cmdstr`;
	#print "\n\n" . $out . "\n\n";
	if ( $out =~ /name:.*/g ) {
		return 1;
	} else {
		return undef;
	};
}

#####################################################################
sub checkEmail {
	my $email = shift || die "no email address specified\n";
	$email = lc($email); # email addresses are case insensitive
	if (defined $validemails->{$email}) {
		$cachehits++;
		return 1;
	} elsif (defined $goners->{$email}) {
		$cachehits++;
		return undef;
	} else {
		my $res = isValidEmail($email);
		if ($res) {
			$validemails->{$email} = 1;
			return 1;
		} else {
			$goners->{$email} = 1;
			return undef;
		}
	}
}

#####################################################################
sub find_datafiles ($) {
	my $dir = shift || die "no dir specified\n";

	File::Find::find(\&wanted, $dir);
}

#####################################################################
sub removefile {
	my $filename = shift || die "no filename specified\n";

	my $cnt = unlink($filename);
	$delcount += $cnt;
	return $cnt;
}

#####################################################################
sub wanted {
	$files++;
	if ( -d $File::Find::name ) {
		$File::Find::name .= "/";
		if ($File::Find::name eq $prefs->{squirrelmail_datadir}) {
			return undef;
		}
		warn "Directory found: $File::Find::name";
		return undef;
	}

	my $filename = basename($File::Find::name);
	my $email = $filename;
	$email =~ s/\.(abook|sig|si\d+|pref)$//;
	if ($email eq $filename) {
		# hm, what kind of file is this???
		if (defined $exclude_files->{$filename}) {
			$ignorecount++;
		} else {
			$unknownfilescount++;
			print "$filename could not be attributed to anything useful.\n";
		};
	};
	unless (checkEmail($email)) { # does not resolve to a valid email
		if ($listfiles) {
			print "$email: DELETE: $File::Find::name\n";
		}
		unless (removefile($File::Find::name)) {
			warn "$File::Find::name was not deleted\n";
		};
	};
}

#######################  MAIN  ######################################
$files = 0;
$cachehits = 0;
$delcount = 0;
$ignorecount = 0;
$unknownfilescount = 0;
find_datafiles( $prefs->{'squirrelmail_datadir'} );

if ($summary || $unknownfilescount > 0) { # do output even if unrequested, when there are unknown files
	print "Checked $files files, $delcount were deleted, $cachehits cache hits, $ignorecount were ignored, $unknownfilescount were of type unknown and are still lurking around.\n";
}
