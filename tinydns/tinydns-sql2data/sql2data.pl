#!/usr/bin/env perl

=head1 NAME

sql2data - Maintain tinydns data file using SQL

=head1 SYNOPSIS

B<sql2data> S<[ B<-b> ]> S<[ B<-c> I<config> ]> S<[ B<-d> I<DSN> ]>
S<[ B<-h> ]> S<[ B<-l>]> S<[ B<-o> I<outfile> ]> S<[ B<-p> I<pwd> ]>
S<[ B<-r> I<root_dir> ]> S<[ B<-u> I<uname> ]> S<[ B<-v> ]> S<[ B<-V> ]>

=head1 DESCRIPTION

B<sql2data> fetches DNS information from an SQL database and dumps them in
tinydns-data format into a file that can be specified.
B<sql2data> executes `make` on successful export/dump.
Backups can be made to the files 'old_data' and 'good_data.cdb'.

Supports Vegadns <http://www.vegadns.org> and IPv6 patched tinydns
<http://www.fefe.de/dns/>.

=head1 OPTIONS

=over 4

=item B<-b>

Make backups of 'data' and 'data.cdb'. Before writing the new data file,
'data' is copied to 'old_data'. If 'make' was executed successfully, the file
'data.cdb' is copied to 'good_data.cdb'.

=item B<-c> I<config>

Read configuration from file I<config>. See B<CONFIGURATION FILE> for syntax.

=item B<-d> I<DSN>

Use I<DSN> as data source name for DBI. Example: "dbi:mysql:database_name"

=item B<-h>

Display help.

=item B<-l>

When B<-l> (leave) is specified, `make` is not executed.

=item B<-o> I<outfile>

Dump records to file outfile instead of 'data'.

=item B<-p> I<pwd>

Specify password for SQL database.

=item B<-r> I<root_dir>

Specify tinydns root directory (containing 'data' and 'data.cdb'). If this
is not specified, the current working directory is used.

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

backup = 0|1

leave = 0|1

dsn = string

root_dir = string

sql_username = string

sql_password = string

sql_tableprefix = string

=head1 FILES

=over 4

=item data data.cdb good_data.cdb old_data

Files being read/written to.

=item Makefile

Used for compiling 'data'. Read-only. See the tinydns default configuration.

=back

=head1 LICENSE

This program is distributed under the terms of the BSD Artistic License.

=head1 AUTHORS

Copyright (c) 2003-2007 Paul Kremer.
The original source was written by Henning Brauer in 2001 and released under
the BSD License.

=head1 CREDITS

Credits go to FSS <http://www.fss.de/> for sponsoring the initial development of
this tool.

Thanks Logan Michels (logan at stfunoob dot com) for the IPv6 patch.

=head1 BUGS

Please send patches in unified GNU diff format to <pkremer[at]spurious[dot]biz>

=head1 SEE ALSO

L<perl(1)>, <http://cr.yp.to/djbdns/tinydns-data.html>, DBI, L<make(1)>, <http://www.vegadns.org/>

=cut

use strict;
use warnings;
use 5.006001;
use DBI;
use File::Copy;
use File::Temp qw /tempfile/;
use Cwd qw/cwd/;
use Getopt::Std;
use vars qw($cvsversion $fullpath);

# initialize
&init();

# command line arguments
my %args;
getopts( "c:d:r:u:o:p:m:bhlvV", \%args );
if ( $args{'h'} ) { &help(); }
if ( $args{'V'} ) { &version(); }

my %Prefs =
  &Preferences( $args{'c'} );   # reads prefs, if given and sets other defaults.

if ( $args{'r'} )
{
	&myverbose("chdir to $args{'r'}");
	if ( -d $args{'r'} )
	{
		chdir $args{'r'} || die "$0 ($$): Cannot chdir to $args{'r'}: $!";
	}
	else
	{
		die("$0 ($$): Cannot chdir to $args{'r'}: $!");
	}
}

# connect to your database
my $dbh = DBI->connect( $args{'d'}, $args{'u'}, $args{'p'} )
  || die "$0 ($$): Cannot connect to db server " . DBI::errstr() . "\n";

my $outputfilename = $args{'o'};

#Backup old File and use the template for the new one
if ( defined( $args{'b'} ) && -e $outputfilename )
{
	&myverbose("Backing up '$outputfilename' to 'old_$outputfilename'");
	File::Copy::copy( $outputfilename, "old_$outputfilename" )
	  || warn(
		"$0 ($$): Can't copy '$outputfilename' to 'old_$outputfilename': $!");
}

my ( $fh, $tempfilename );
if ( defined( $args{'r'} ) )
{
	( $fh, $tempfilename ) =
	  tempfile( 'dataXXXXXXXXX', DIR => $args{'r'}, UNLINK => 1 );
}
else
{
	( $fh, $tempfilename ) =
	  tempfile( 'dataXXXXXXXXX', DIR => cwd(), UNLINK => 1 );
}
close($fh);
&myverbose("Temp file: $tempfilename");
&myverbose("Rewriting '$outputfilename'");

open( $fh, ">$tempfilename" ) || die("$0 ($$): Can't open '$tempfilename' for writing: $!");

############################################
#fetch domain-data
my $stmt = sprintf("SELECT domain_id, domain, status FROM %sdomains WHERE status='active' ORDER BY domain", $Prefs{'sql_tableprefix'} );
my $sth = $dbh->prepare($stmt);
$sth->execute() || warn("problem executing sql: $stmt");
my $dref = undef;
while ( $dref = $sth->fetchrow_hashref() )
{
	#SOA comment line, new domain:
	print $fh "# DOMAIN ID: $dref->{domain_id} DOMAIN: $dref->{domain}\n";

	#fetch the records for this domain:
	my $pf = $Prefs{'sql_tableprefix'};

	my $sql =
	  sprintf("SELECT host, type, val, distance, ttl FROM ${pf}records WHERE domain_id=%s",
		$dbh->quote( $dref->{domain_id} ) );
	my $st2 = $dbh->prepare($sql);
	$st2->execute || warn("problem executing sql");
	while ( my $r = $st2->fetchrow_hashref() )
	{
		# if value empty: don't put into '$outputfilename', skip this nsentry
		my $datarow = buildRowFrom( $dref, $r );
		print $fh $datarow;
	}
	$st2->finish();

}
$sth->finish;
close($fh) || warn("$0 ($$): Can't close file '$tempfilename': $!");
move( $tempfilename, $outputfilename )
  || warn("$0 ($$): Can't move new '$tempfilename' to '$outputfilename': $!");

my $result = undef;
if ( !defined( $args{'l'} ) )
{    # compile!, no 'leave' option
	$result = &make();
}
else
{
	&myverbose("NOT executing 'make -s'");
	$result = 2;
}

if ( !defined( $args{'l'} ) && $result == 1 )
{
	if ( defined( $args{'b'} ) )
	{
		&myverbose("backing'data.cdb' up to 'good_data.cdb'");
		File::Copy::copy( "data.cdb", "good_data.cdb" )
		  || warn("$0 ($$):Can't copy 'data.cdb' to 'good_data.cdb': $!");
	}
}

$dbh->disconnect();

exit();

#################################################
# parseSOA ( $recordref )
#
# returns a hash reference with SOA information
#
sub parseSOA
{
	my $soa = shift || die "die missing parameter soa";

	#These values are accepted by DENIC and CORE
	my $default = undef;
	$default->{ttl}     = 86400;
	$default->{refresh} = 10000;
	$default->{retry}   = 3600;
	$default->{expire}  = 604800;
	$default->{min}     = 86400;

	my $result = undef;
	my $tmp    = undef;
	( $result->{tldemail}, $result->{tldhost}, $tmp ) =
	  split( /:/, $soa->{host}, 3 );

	my @ttls_soa = split( /:/, $soa->{val} );

	# ttl
	if ( $soa->{ttl} eq '' )
	{
		$result->{ttl} = $default->{ttl};
	}
	else
	{
		$result->{ttl} = $soa->{ttl};
	}

	# refresh
	if ( $ttls_soa[0] eq '' )
	{
		$result->{refresh} = $default->{refresh};
	}
	else
	{
		$result->{refresh} = $ttls_soa[0];
	}

	# retry
	if ( $ttls_soa[1] eq '' )
	{
		$result->{retry} = $default->{retry};
	}
	else
	{
		$result->{retry} = $ttls_soa[1];
	}

	# expiration
	if ( $ttls_soa[2] eq '' )
	{
		$result->{expire} = $default->{expire};
	}
	else
	{
		$result->{expire} = $ttls_soa[2];
	}

	# min
	if ( $ttls_soa[3] eq '' )
	{
		$result->{minimum} = $default->{min};
	}
	else
	{
		$result->{minimum} = $ttls_soa[3];
	}
	return $result;
}

sub buildIPv6AAAA # unused right now
{
	# there are 2 ways to create an AAAA record in tinydns, one which is done through the
	# native support in tinydns for generic dns records (:) and one after patching
	# tinydns with patches from http://www.fefe.de/dns/

	my $r = shift;
	my $s = '';	
	
	# The code below builds the generic entry using a ":" entry
	# It might have bugs with regard to compressed/uncompressed IP addresses. # TODO
	
	my ( $a, $b, $c, $d, $e, $f, $g, $h ) = split /:/, $r->{val};
	if ( ! defined $h ) {
	    warn "didn't get a valid-looking IPv6 address\n";
	    $s = '';
	}
	else
	{
	    $a = escapeHex( sprintf "%04s", $a );
	    $b = escapeHex( sprintf "%04s", $b );
	    $c = escapeHex( sprintf "%04s", $c );
	    $d = escapeHex( sprintf "%04s", $d );
	    $e = escapeHex( sprintf "%04s", $e );
	    $f = escapeHex( sprintf "%04s", $f );
	    $g = escapeHex( sprintf "%04s", $g );
	    $h = escapeHex( sprintf "%04s", $h );
    	$s = ":" . $r->{'host'} . ":28:" . "$a$b$c$d$e$f$g$h" . 	":" . $r->{'ttl'} . "\n";
	}
	return $s;
}

=item buildRowFrom ( $d, $r )

builds a tinydns-data ascii line from domainref and recordref hash refs and returns it.

=cut
sub buildRowFrom
{
	my $domain = shift || die "missing parameter domain";
	my $r = shift || die "missing parameter record";

	my $s = undef;

	my $null = '';

	# skip if input is not complete:
	if (length($r->{host}) <1 or not defined ($r->{val}) or length($r->{val}) < 1)
	{
		return "";
	}

	if ( $r->{type} =~ /^A$/ )
	{
		$s = "+" . escapeText($r->{host}) . ":" . $r->{val} . ":" . $r->{ttl} . "\n";
	}
	elsif ( $r->{type} =~ /^3$/ )
	{
		# please see comment below
		$r->{val} =~ s/:/$null/g;
		$s = "3" . escapeText($r->{host}) . ":" . $r->{val} . ":" . $r->{ttl} . "\n";
	}
	elsif ( $r->{type} =~ /^6$/ )
	{
		# for IPv6 addresses to work properly with the patches from http://www.fefe.de/dns/, they must
		# be formatted in uncompressed form and contain "redundant" zeros, as in this example:
		# 2001:0000:4137:e38a:0000:f227:2b35:361d
		$r->{val} =~ s/:/$null/g;
		$s = "6" . escapeText($r->{host}) . ":" . $r->{val} . ":" . $r->{ttl} . "\n";
	}
	elsif ( $r->{type} =~ /^M$/ )
	{
		$s = "\@" . escapeText($r->{host}) . "::" . $r->{val} . ":" . $r->{distance} . ":" . $r->{ttl} . "\n";
	}
	elsif ( $r->{type} =~ /^N$/ )
	{
		$s = "&" . escapeText($r->{host}) . "::" . $r->{val} . ":" . $r->{ttl} . "\n";
	}
	elsif ( $r->{type} =~ /^P$/ )
	{
		$s = "^" . escapeText($r->{host}) . ":" . $r->{val} . ":" . $r->{ttl} . "\n";
	}
	elsif ( $r->{type} =~ /^T$/ )
	{
		$r->{val} =~ s/:/\\072/;
		$s = "'" . escapeText($r->{host}) . ":" . $r->{val} . ":" . $r->{ttl} . "\n";
	}
	elsif ( $r->{type} =~ /^C$/ )
	{
		$s = "C" . escapeText($r->{host}) . ":" . $r->{val} . ":" . $r->{ttl} . "\n";
	}
	elsif ( $r->{type} =~ /^S$/ )
	{
		my $soa = parseSOA($r);
		$s = "Z" . escapeText($domain->{domain}) . ":" . escapeText($soa->{tldhost}) . ":" . escapeText($soa->{tldemail}) . "::" . $soa->{refresh} . ":" . $soa->{retry} . ":" . $soa->{expire} . ":" . $soa->{minimum} . ":" . $soa->{ttl} . "\n";
	}
	else
	{
		warn("Got data that I can't parse into tinydns format!");
		$s = "#hm?\n";
	}

	return $s;
}

sub escapeHex
{
    # takes a 4 character hex value and converts it to two escaped numbers
    my $line = pop @_;
    my @chars = split //, $line;

    my $out = sprintf "\\%.3lo", hex "$chars[0]$chars[1]";
    $out = $out . sprintf "\\%.3lo", hex "$chars[2]$chars[3]";

    return( $out );
}

sub escapeText
{
    my $line = pop @_;
    my $out;
    my @chars = split //, $line;

    foreach my $char ( @chars ) {
	if ( $char =~ /[\r\n\t: \\\/]/ ) {
	    $out = $out . sprintf "\\%.3lo", ord $char;

	}
	else {
	    $out = $out . $char;

	}

    }
    return( $out );
}

#################################################
# make ( )
#
# executes 'make -s' safely
#
sub make
{
	&myverbose("executing 'make -s'");
	my @command = ( 'make', '-s' );
	if ( system(@command) != 0 )
	{
		my $exit_value  = $? >> 8;
		my $signal_num  = $? & 127;
		my $dumped_core = $? & 128;
		warn("$0 ($$): system(@command) failed: $?");
		warn("$0 ($$): exit_value: $exit_value signal_num: $signal_num dumped_core: $dumped_core\n");
		return 0;
	}
	else
	{
		return 1;
	}
}

#################################################
sub init
{
	$fullpath = $0;    # full path to this program
	$0 =~ s!.*/!!;     # basename of this program
	$|          = 1;   # autoflush output
	$cvsversion =q$Id: sql2data.pl 405 2007-08-26 21:18:05Z pkremer $;# TODO: switch to subversion!
}

#################################################
sub myverbose
{
	print "$0 ($$) v: '@_'\n" if $args{'v'};
}

#################################################
sub help
{
	print "Feeding myself to perldoc, please wait....\n";
	exec( 'perldoc', '-t', $fullpath ) or die "$0: can't fork: $!\n";
	exit(0);
}

#################################################
sub version
{
	my @cvs     = split( ' ', $cvsversion );
	my $VERSION = '2.0';
	my $v       = $cvs[1] . " $VERSION [" . $cvs[3] . "]";
	$v =~ s/,v\b//;
	print $v, "\n";
	exit 0;
}

#################################################
sub Preferences
{

	# read config file & set defaults
	my $rc = shift;
	my %Prefs;
	return %Prefs unless defined $rc;
	if ( -e $rc )
	{
		open( RC, "<$rc" ) || die("$0 ($$): error opening '$rc': $!");
		while (<RC>)
		{
			chomp;
			s/#.*//;
			s/^\s+//;
			s/\s+$//;
			next unless length;
			my ( $var, $value ) = split( /\s*=\s*/, $_, 2 );
			$Prefs{ lc($var) } = $value;
		}
		close RC || warn("$0 ($$): close error on '$rc': $!");
	}
	if ( defined( $Prefs{'verbose'} ) )
	{
		if (   int( $Prefs{'verbose'} ) eq $Prefs{'verbose'}
			&& int( $Prefs{'verbose'} ) == 1 )
		{
			$args{'v'} = 1;
		}
	}
	if ( defined( $Prefs{'backup'} ) )
	{
		if (   int( $Prefs{'backup'} ) eq $Prefs{'backup'}
			&& int( $Prefs{'backup'} ) == 1 )
		{
			$args{'b'} = 1;
		}
	}
	if ( defined( $Prefs{'leave'} ) )
	{
		if (   int( $Prefs{'leave'} ) eq $Prefs{'leave'}
			&& int( $Prefs{'leave'} ) == 1 )
		{
			$args{'l'} = 1;
		}
	}
	if ( defined( $Prefs{'sql_username'} ) )
	{
		if ( !$args{'u'} )
		{
			$args{'u'} = $Prefs{'sql_username'};
		}
	}
	if ( defined( $Prefs{'sql_password'} ) )
	{
		if ( !$args{'p'} )
		{
			$args{'p'} = $Prefs{'sql_password'};
		}
	}
	if ( !defined( $Prefs{'sql_tableprefix'} ) )
	{
		$Prefs{'sql_tableprefix'} = 'ddns_';
	}
	if ( defined( $Prefs{'dsn'} ) )
	{
		if ( !$args{'d'} )
		{
			$args{'d'} = $Prefs{'dsn'};
		}
	}
	if ( defined( $Prefs{'root_dir'} ) )
	{
		if ( !$args{'r'} )
		{
			$args{'r'} = $Prefs{'root_dir'};
		}
	}
	if ( defined( $Prefs{'outfile'} ) )
	{
		if ( !$args{'o'} )
		{
			$args{'o'} = $Prefs{'outfile'};
		}
	}
	if ( defined( $args{'v'} ) )
	{
		while ( my ( $key, $value ) = each(%Prefs) )
		{
			&myverbose("rc value: $key -> $value");
		}
	}
	return %Prefs;
}

