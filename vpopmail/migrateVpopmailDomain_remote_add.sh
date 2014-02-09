#!/bin/bash

# $Id: migrateVpopmailDomain_remote_add.sh 326 2006-12-27 11:58:03Z pkremer $
#
# Sister script to the migrateVpopmailDomain.sh script.
#

# Configuration:
VPOPMAILDIR=/home/vpopmail

###################### MAIN ###############################
if [ $# -lt 1 ]; then
	echo "Usage: `basename $0` virtualdomain [aliasdomains]" >&2
	exit 1
fi

dom=$1
shift
aliasdomains="$@"

/usr/bin/qmailctl stop
# add the domain with a random password (-r) so nobody can login during the migration
# (qmailadmin for example)
$VPOPMAILDIR/bin/vadddomain $dom -r
for a in $aliasdomains
do
	echo "Adding alias domain $a"
	$VPOPMAILDIR/bin/vaddaliasdomain $dom $a
done