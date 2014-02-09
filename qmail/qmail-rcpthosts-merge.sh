#!/bin/bash

# $Id: qmail-rcpthosts-merge 232 2005-04-08 12:25:37Z pkremer $
#
# manage host-specific rcpthosts for qmail
#
# a directory rcpthosts.d/ contains per-host rcpthosts files
# each file has the name of the hostname

# - generates rcpthosts.d/$HOSTNAME for the local host
# - merges rcpthosts.d/ into /var/qmail/control/ files
# - runs qmail/bin/qmail-newmrh to rebuild cdb files

# Author: Paul Kremer, 2005
# Copyright: BSD Artistic License

# Configuration:
QD=/var/qmail # qmail installation dir
RCPTHOSTSDIR=/var/qmail/control/rcpthosts.d # rcpthosts.d directory

###################### MAIN ###############################
NAME="qmail-rcpthosts-merge" # used to identify ourselves ;
HOST=`hostname` # this hostname
cd "$QD/control/"
sed 's/:.*//' < virtualdomains | cat - locals | sort -u > $RCPTHOSTSDIR/$HOST
echo "$NAME: Created rcpthost file for locally hosted virtualdomains"

tmp=${TMPDIR-/tmp}
tmp=$tmp/$NAME.$RANDOM.$RANDOM.$RANDOM.$$
(umask 077 && mkdir $tmp) || {
	echo "$NAME: Could not create temporary directory! Exiting." 1>&2
	exit 1
}
RCPT_TMP=$tmp/rcpthosts.merged
RCPTMORE_TMP=$tmp/morercpthosts.merged
touch $RCPT_TMP
touch $RCPTMORE_TMP
COUNT=0
for file in $( find $RCPTHOSTSDIR/ -type f -name '*' )
do
	cat $file | while read LINE
	do
		COUNT=$(($COUNT+1))
		if [ $COUNT -lt 50 ]; then
			#echo "$COUNT $LINE"
			echo "$LINE" >> $RCPT_TMP
		else
			#echo "BIG $COUNT $LINE"
			echo "$LINE" >> $RCPTMORE_TMP
		fi
	done
done
mv $RCPT_TMP $QD/control/rcpthosts
mv $RCPTMORE_TMP $QD/control/morercpthosts
rm -rf $tmp
echo "$NAME: Merged all rcpthost files into local qmail control files"

# rebuild the cdb database for morercpthosts:
$QD/bin/qmail-newmrh || exit 1
echo "$NAME: ran qmail-newmrh - prepared morercpthosts for qmail-smtpd"

# AFAIK, no qmail component needs to re-read these files...