#!/bin/bash

# $Id: qmail-rcpthosts-sync 235 2005-04-08 12:37:28Z pkremer $
#
# manage rcpthosts for multiple qmail instances
#
# relies on "fileq" and "qmail-rcpthosts_merge" to put or get new rcpthost files
#
# Author: Paul Kremer, 2005
# Copyright: BSD Artistic License

# Configuration:
RCPTHOSTSDIR=/var/qmail/control/rcpthosts.d # rcpthosts.d directory
MERGER=/var/qmail/bin/qmail-rcpthosts-merge # path to qmail-rcpthosts_merge
FILEQ=fileq # username for file queueing
PUTQUEUE=/var/local/fileq/out/rcpthosts.d/ # outgoing queue
GETQUEUE=/var/local/fileq/in/rcpthosts.d/  # incoming queue


###################### MAIN ###############################
NAME="qmail-rcpthosts-sync"
if [ $# -ne 1 ]; then
	echo "Usage: `basename $0` [put|get]" >&2
	exit 1
fi

id $FILEQ > /dev/null || exit 1
HOST=`hostname`

if [ "x${1}" == "xput" ]; then
	if [ ! -d $PUTQUEUE ]; then
		echo "$NAME: '$PUTQUEUE' does not exist!" >&2
		exit 1
	fi
	$MERGER
	if [ -f $RCPTHOSTSDIR/${HOST} ]; then
		cp $RCPTHOSTSDIR/${HOST} $PUTQUEUE/
		chown $FILEQ:$FILEQ $PUTQUEUE/*
	else
		echo "$NAME: No file at '$RCPTHOSTSDIR/${HOST}' to be queued"
	fi
	echo "$NAME: done putting local rcpthosts file into outgoing queue"
	exit
fi

if [ "x${1}" == "xget" ]; then
	if [ ! -d $GETQUEUE ]; then
		echo "$NAME: '$GETQUEUE' does not exist!" >&2
		exit 1
	fi
	if [ -d $GETQUEUE ]; then
		COUNT=0
		for file in $( find $GETQUEUE -type f -name '*' )
		do
			COUNT=$(($COUNT+1))
			chown root:root $file
			chmod 644 $file
			mv $file $RCPTHOSTSDIR/
		done
		if [ $COUNT -lt 1 ]; then
			echo "$NAME: no alien rcpthosts files found in '$GETQUEUE'"
			exit
		fi
		echo "$NAME: done getting alien rcpthosts files into rcpthosts.d pool"
		$MERGER
	else
		echo "$NAME: No incoming queue at '$GETQUEUE'"
	fi
	exit
fi

echo "Usage: `basename $0` [put|get]" >&2
exit 1