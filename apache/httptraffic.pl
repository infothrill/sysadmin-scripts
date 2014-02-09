#!/usr/bin/perl
my $ID = q$Id: httptraffic.pl,v 1.6 2005/08/26 13:52:03 pkremer Exp $;

# use perldoc to see the documentation of this script or look below

##############################################################################
# Site configuration
##############################################################################

use warnings;
use strict;
use POSIX qw(strftime);
use Getopt::Long;
use File::Spec;
use DBI;

##############################################################################
# Implementation
##############################################################################

# Parse command-line options.
my $o = undef; # options
Getopt::Long::config ('bundling', 'no_ignore_case');
GetOptions (
	'help|H' => \$o->{help},
	'version|v' => \$o->{version},
	'verbose|V' => \$o->{verbose},
	'quiet|q' => \$o->{quiet},
	'host|h=s' => \$o->{host},
	'db|d=s' => \$o->{db},
	'user|u=s' => \$o->{user},
	'password|p=s' => \$o->{password},
	'table|t=s' => \$o->{table},
	'report|r' => \$o->{report},
	'year|y=s' => \$o->{year},
	'month|m=s' => \$o->{month},
	) or exit 1;

if ($o->{version}) {
	my @cvs = split (' ', $ID);
	my $VERSION = '0.1';
	my $v = $cvs[1] . " $VERSION [".$cvs[3]. "]";
	$v =~ s/,v\b//;
	print $v, "\n";
	exit 0;
}

if ($o->{help}) {
	print "Feeding myself to perldoc, please wait....\n";
	exec ('perldoc', '-t', $0) or die "$0: can't fork: $!\n";
}
unless ( $o->{table} ) { $o->{table} = 'httptraffic'; };
unless ( $o->{host} && $o->{db} && $o->{user} ) { die "$0: Syntax error: need all off [hdu] options!"; };
unless ( $o->{password} ) { $o->{password} = undef; };

my $dbh = DBI->connect("DBI:mysql:$o->{db}:$o->{host}", $o->{user}, $o->{password}) || die "$0: Cannot connect to db server $DBI::errstr\n";

if (! $o->{report}) {
	###################################################################
	####### DATABASE UPDATE
	###################################################################
	my $bd = shift @ARGV; # base directory
	if (! -d $bd) {
		die "$0: directory $bd does not exist!";
	};
	opendir(DIR, $bd) || die "$0: could not open directory $bd: $!";
	my $counter = 0;
	foreach ( readdir (DIR) ) {
		next if (/^\./); # deny EVERYTHING starting with a dot
		my $domain = $_;
		my $domaindir = File::Spec->catdir($bd,$domain);
		unless (-d $domaindir) { # deny FILES
			#warn("$0: not a directory: $domaindir") unless $o->{quiet};
			next;
		}
		my $webalizerhist = File::Spec->catfile($domaindir,'webalizer.hist');
		unless (-r $webalizerhist) { # non webalizer.hist dirs
			warn("$0: no 'webalizer.hist' found in $domaindir") unless $o->{quiet};
			next;
		};
		print "$domain\n" if $o->{verbose};
		my $parsed_hist = webalizerhist_parse($webalizerhist);
		my $select = $dbh->prepare("SELECT * FROM $o->{table} WHERE domain=? AND year=? AND month=?");
		my $insert = $dbh->prepare("INSERT INTO $o->{table} (domain,month,year,hits, files, sites, kbytes, firstday, lastday, pages, visits) VALUES (?,?,?,?,?,?,?,?,?,?,?)");
		my $update = $dbh->prepare("UPDATE $o->{table} SET hits = ?, files = ?, sites = ?, kbytes = ?, firstday = ?, lastday = ?, pages = ?, visits = ?, mtime = ? WHERE domain = ? AND year = ? AND month = ?");
		foreach my $r (@{$parsed_hist}) {
			$select->execute($domain, $r->{year}, $r->{month});
			if ($DBI::errstr) { # catches invalid table name
				die "$0: Database error: $DBI::errstr\n";
			};
			if (my $result = $select->fetchrow_hashref()) { # needs compare!
				if ($r->{lastday} > $result->{lastday} || $r->{hits} > $result->{hits}) { # new data!
					my $timestamp = strftime "%Y%m%d%H%M%S", localtime(time());
					$update->execute($r->{hits} , $r->{files} , $r->{sites} , $r->{kbytes} , $r->{firstday} , $r->{lastday} , $r->{pages} , $r->{visits}, $timestamp, $domain, $r->{year}, $r->{month});
					print "\tUpdated record: $r->{year} $r->{month} $domain\n" if $o->{verbose};
				}
			} else { # INSERT
				$insert->execute($domain, $r->{month}, $r->{year} , $r->{hits} , $r->{files} , $r->{sites} , $r->{kbytes} , $r->{firstday} , $r->{lastday} , $r->{pages} , $r->{visits});
				print "\tNew record: $r->{year} $r->{month} $domain\n" if $o->{verbose};
			}
		}
		$counter++;
	};
	closedir(DIR);
	print "Total of $counter domains processed.\n" if $o->{verbose};
} else {
	###################################################################
	####### GENERATE REPORT
	###################################################################
	my $domain = undef;
	if (@ARGV) { $domain = shift @ARGV; };
	printHeader($o->{year}, $o->{month}, $domain);
	my $sum = fetchTotalTrafficFromDB($o->{year}, $o->{month}, $domain);
	print "Total httptraffic: $sum kB or ".kbytes_to_human($sum)."\n\n";

	if ( ! $domain && ($o->{month} || $o->{year}) ) { # all domains per month/year overview
		if ($o->{month} && $o->{year}) {
			my $stmt = "SELECT domain,kbytes FROM $o->{table} WHERE ";
			my @where_conds = ();
			my @execute_params = ();
			if ($o->{year}) { push(@where_conds, 'year = ?');  push(@execute_params, $o->{year}); };
			if ($o->{month}) { push(@where_conds, 'month = ?');  push(@execute_params, $o->{month}); };
			$stmt .= join(' AND ', @where_conds);
			$stmt .= ' ORDER BY kbytes DESC';
			my $select = $dbh->prepare($stmt);
			$select->execute(@execute_params);
			my $maxtraffic = undef;
			while (my $result = $select->fetchrow_hashref()) {
				unless (defined $maxtraffic) { $maxtraffic = $result->{kbytes}; };
				print $result->{domain} . ": ".$result->{kbytes}." kB or ".kbytes_to_human($result->{kbytes})."\n";
				my $percent = (100 *  $result->{kbytes} ) / $maxtraffic;
				print "[" . '=' x (72*$percent/100) . "]\n";
			}
			unless ($maxtraffic) {
				print "No records found!\n";
				exit;
			}
		} elsif ($o->{year}) {
			# SELECT SUM(kbytes) as kbytes,month FROM httptraffic WHERE year='2004' GROUP by month ORDER by month ASC
			# find the maxtraffic:
			my $stmt = "SELECT SUM(kbytes) as kbytes FROM $o->{table} WHERE year = ? GROUP by month ORDER by kbytes DESC LIMIT 0,1";
			my $select = $dbh->prepare($stmt);
			$select->execute($o->{year});
			my $maxtraffic = 0;
			if (my $res = $select->fetchrow_arrayref() ) {
				$maxtraffic = $res->[0];
			} else {
				print "No records found!\n";
				exit;
			}
			$stmt = "SELECT SUM(kbytes) as kbytes,month FROM $o->{table} WHERE year = ? GROUP by month ORDER by month DESC";
			$select = $dbh->prepare($stmt);
			$select->execute($o->{year});
			while (my $result = $select->fetchrow_hashref()) {
				print $result->{month}.'/'.$o->{year} . ": ".$result->{kbytes}." kB or ".kbytes_to_human($result->{kbytes})."\n";
				my $percent = (100 *  $result->{kbytes} ) / $maxtraffic;
				print "[" . '=' x (72*$percent/100) . "]\n";
			}
			unless ($maxtraffic) {
				print "No records found!\n";
				exit;
			}
		} else {
			print "error: cannot generate a monthly report with no year specified\n";
			exit 1;
		}
	} elsif ($domain) { # overview for one domain
		# find the maxtraffic:
		my $stmt = "SELECT kbytes FROM $o->{table} WHERE ";
		my @where_conds = ();
		push(@where_conds, 'domain = ?');
		my @execute_params = ();
		push(@execute_params, $domain);
		if ($o->{year}) { push(@where_conds, 'year = ?');  push(@execute_params, $o->{year}); };
		if ($o->{month}) { push(@where_conds, 'month = ?');  push(@execute_params, $o->{month}); };
		$stmt .= join(' AND ', @where_conds);
		$stmt .= ' ORDER BY kbytes DESC LIMIT 0,1';
		my $select = $dbh->prepare($stmt);
		$select->execute(@execute_params);
		my $maxtraffic = 0;
		if (my $res = $select->fetchrow_arrayref() ) {
			$maxtraffic = $res->[0];
		} else {
			print "No records found!\n";
			exit;
		}
		$stmt = "SELECT year, month, kbytes FROM $o->{table} WHERE ";
		@where_conds = ();
		push(@where_conds, 'domain = ?');
		@execute_params = ();
		push(@execute_params, $domain);
		if ($o->{year}) { push(@where_conds, 'year = ?');  push(@execute_params, $o->{year}); };
		if ($o->{month}) { push(@where_conds, 'month = ?');  push(@execute_params, $o->{month}); };
		$stmt .= join(' AND ', @where_conds);
		$stmt .= ' ORDER BY year DESC,month DESC';
		$select = $dbh->prepare($stmt);
		$select->execute(@execute_params);
		while (my $result = $select->fetchrow_hashref()) {
			print $result->{year} .'/'. $result->{month} . ": ".$result->{kbytes}." kB or ".kbytes_to_human($result->{kbytes})."\n";
			my $percent = (100 *  $result->{kbytes} ) / $maxtraffic;
			print "[" . '=' x (72*$percent/100) . "]\n";
		}
	} else { # huh? TODO
	}
}

# prints an ascii header for the generated report
# params: year, month, domain
sub printHeader {
	my ($year, $month, $domain) = @_;
	print "httptraffic.pl report for ";
	my @list = ();
	if ($month) { push(@list, "month $month"); };
	if ($year) { push(@list, "year $year"); };
	if ($domain) { push(@list, "domain $domain"); };
	if (@list ) { print join(', ', @list); } else { print 'everything available'; };
	print " (Generated: ".localtime().")\n\n";
}

# fetches the sum of traffic for the given paramaters
# params: year, month, domain
sub fetchTotalTrafficFromDB {
	my ($year, $month, $domain) = @_;
	my $stmt = "SELECT SUM(kbytes) FROM $o->{table}";
	my @where_conds = ();
	my @execute_params = ();
	if ($year) { push(@where_conds, 'year = ?');  push(@execute_params, $year); };
	if ($month) { push(@where_conds, 'month = ?');  push(@execute_params, $month); };
	if ($domain) { push(@where_conds, 'domain = ?');  push(@execute_params, $domain); };
	if (@where_conds) {
		$stmt .= ' WHERE ';
		$stmt .= join(' AND ', @where_conds);
	}
	my $select = $dbh->prepare($stmt);
	$select->execute(@execute_params);
	my $res = $select->fetchrow_arrayref();
	return 0 unless $res->[0];
	return $res->[0];
}

# kbytes_to_human - convert a number of kbytes to a more human-readable
# format (e.g. MB, GB, etc).
sub kbytes_to_human {
	my %UNITS = (1 => "kB",
		1024 => "MB",
		1024 ** 2 => "GB",
		1024 ** 3 => "TB",
		1024 ** 4 => "PB"
	);

	my $nkbytes = shift;
	my $nunits;
	my $units;

	foreach my $divisor (sort { $a <=> $b } keys %UNITS) {
		last if $nkbytes < $divisor;
		$units = $UNITS{$divisor};
		$nunits = $nkbytes / $divisor;
	}

	$nkbytes = $nunits ? sprintf ("%.1f %s", $nunits, $units) : $nkbytes;
	return $nkbytes;
}

# parameter: $parsedHist, fieldname, year, month
# return: value or undef if not found
sub webalizerhist_getFieldForYearMonth {
	my @_fieldnames = qw (month year hits files sites kbytes firstday lastday pages visits);
	my $parsed_hist = shift || die "$0: missing parameter 'parsed_hist'";
	my $field = shift;
	my $y = shift;
	my $m = shift;
	foreach my $month (@{$parsed_hist}) {
		if ($month->{month} eq $m && $month->{year} eq $y) {
			unless (defined $month->{$field} ) {
				warn("$0: field '$field' is invalid!") unless $o->{quiet};
				warn ("$0: valid fieldnames: ". join(' ', @_fieldnames))  unless $o->{quiet};
				return undef;
			}
			return $month->{$field};
		};
	};
	warn("$0: could not find a record for month '$m' and year '$y'!") unless $o->{quiet};
	return undef;
}

# paramater: filename of a webalizer.hist file
# return: array of hashes
sub webalizerhist_parse {
	my $f = shift || die "$0: no filename given!";
	die "$0: file '$f' does not exist or is not readable!" unless (-r $f);
	open(F, "<$f") || die "$0: could not open file '$f': $!";
	my $records = [];
	while (<F>) {
		my $line = $_;
		next if $line =~ /^#/; # skip comment lines
		chomp $line;
		my @splitted = split(/ /, $line);
		die "$0: error parsing $f" if (@splitted != 10);
		my $m = {};
		$m->{month} = shift @splitted;
		$m->{year} = shift @splitted;
		$m->{hits} = shift @splitted;
		$m->{files} = shift @splitted;
		$m->{sites} = shift @splitted;
		$m->{kbytes} = shift @splitted;
		$m->{firstday} = shift @splitted;
		$m->{lastday} = shift @splitted;
		$m->{pages} = shift @splitted;
		$m->{visits} = shift @splitted;
		push(@{$records}, $m);
	};
	close(F);
	return $records;
}

##############################################################################
# Documentation
##############################################################################

=head1 NAME

httptraffic.pl - Merge webalizer .hist files into a MySQL database and generate reports

=head1 SYNOPSIS

httptraffic.pl [B<-HqvV>] [B<-h> hostname] [B<-d> database] [B<-u> user] [B<-p> password] [B<-t> tablename] [B<-m> month] [B<-y> year] I<basedirectory>

httptraffic.pl [B<-HqvV>] [B<-h> hostname] [B<-d> database] [B<-u> user] [B<-p> password] [B<-t> tablename] [B<-m> month] [B<-y> year] [B<-r>] I<domainname>

=head1 DESCRIPTION

B<httptraffic.pl> overcomes a missing feature of webalizer: monitoring
overall statistics for longer than only the last 12 months. It uses
a MySQL database to save and/or analyze the statistics generated
by the webalizer program.

httptraffic.pl has two modes of operation: In database update
mode, it gathers data from history files generated by webalizer and merges
them into the database, and in report generation mode, it generates
reports from the database.

=head2 Database update

In database update mode (the default), httptraffic.pl parses the monthly
history files generated by the I<webalizer> program and
merges the parsed data into a MySQL database.
The input is taken from the specified I<basedirectory> which is supposed
to contain one directory per domain, in which the webalizer output can be found.

Example: If you specify /var/wwwstats/ as the I<basedirectory>, the following history
files will be read:

   /var/wwwstats/somedomain.org/webalizer.hist
   /var/wwwstats/outer.galaxy.net/webalizer.hist
   /var/wwwstats/test.com/webalizer.hist
   ...

httptraffic.pl does not erase records for months older than one year, unlike webalizer does.
In real life, this script can be used to keep monthly records of access statistics generated by
the webalizer program and subsequently use it to generate reports.
If webalizer is run via the cron facility, it is most likely that httptraffic.pl also should be run
via cron.

=head2 Report generation

The report generation mode is entered by specifying the -r option.
The report can be done for a specific year and/or month and/or for all domains
or only a specific domain. By default, it generates cross-domain totals. If you want to
have a report for a specific domain, simply give the domain name as last
parameter.

=head1 OPTIONS

=over 4

=item B<-d>, B<--database> database

Specify the MySQL database.

=item B<-h>, B<--host> hostname

Specify the MySQL hostname.

=item B<-H>, B<--help>

Print out this documentation (which is done simply by feeding the script to
C<perldoc -t>).

=item B<-m>, B<--month> month

Specify the month for the report to be generated.

=item B<-p>, B<--password> password

Specify the MySQL password.

=item B<-q>, B<--quiet>

Do not print anything. Be quiet.

=item B<-r>, B<--report>

Generate a report. Do not update the database.

=item B<-t>, B<--table> tablename

Specify the name of the SQL table. Default: 'httptraffic'.

=item B<-u>, B<--user> username

Specify the MySQL username.

=item B<-v>, B<--version>

Print the version of B<multilog-stamptail> and exit.

=item B<-V>, B<--verbose>

Print more information during execution.

=item B<-y>, B<--year> year

Specify the year for the report to be generated.

=back

=head1 EXAMPLES

   httptraffic.pl --verbose /var/wwwstats/

will update the database using the webalizer.hist files found within subdirectories of the directory /var/wwwstats/

   httptraffic.pl  -r -y 2005

will generate a cross-domain traffic report for the year 2005

   httptraffic.pl  -r -y 2005 example.com

will generate a monthly traffic report for the domain example.com in the year 2005

=head1 SQL table

This script needs one SQL table with the following structure (in MySQL syntax):

   CREATE TABLE `httptraffic` (
     `domain` varchar(255) NOT NULL default '0',
     `month` tinyint(4) NOT NULL default '0',
     `year` int(11) NOT NULL default '0',
     `hits` int(11) NOT NULL default '0',
     `files` int(11) NOT NULL default '0',
     `sites` int(11) NOT NULL default '0',
     `kbytes` int(11) NOT NULL default '0',
     `firstday` tinyint(4) NOT NULL default '0',
     `lastday` tinyint(4) NOT NULL default '0',
     `pages` int(11) NOT NULL default '0',
     `visits` int(11) NOT NULL default '0',
     `mtime` timestamp(14) NOT NULL,
     PRIMARY KEY  (`domain`,`month`,`year`)
   ) TYPE=MyISAM;

=head1 SEE ALSO

See L<http://www.mrunix.net/webalizer/> for information on the webalizer program.

The current version of this program is available from its web page at
L<http://spurious.biz/~pkremer/projects/scripting/#perl>.

=head1 BUGS

Report bugs to pkremer [at] spurious [dot] biz

=head1 COPYRIGHT AND LICENSE

Copyright 2005, Paul Kremer.

This program is free software; you may redistribute it and/or modify it
under the same terms as Perl itself.

=head1 AUTHORS

Paul Kremer <pkremer [at] spurious [dot] biz>

=cut