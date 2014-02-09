#!/bin/bash

# $Id: migrateVpopmailDomain.sh 326 2006-12-27 11:58:03Z pkremer $
#
# Abstract
#
# migrate vpopmail/qmail based virtualdomains from one host to another
# without data loss and without major service interuption
#
# Description
#
# The script automates the migration of a domain (including its alias domains)
# using rsync, ssh, and the normal vpopmail/qmail programs.
# The migration consists of several steps:
# - check the local existance of the domain
# - if the vpopmail authentication backend is not cdb, use vconvert to
#   convert the authentication data to cdb (this has no impact on the installation!)
# - do an initial rsync of the email data
# - stop qmail on new host and add the domains and aliases on the new host
# - stop local POP3/IMAP daemons
# - remove virtualdomains from local qmail config and add smtproutes
# - start local qmail
# - run rsync one last time (remote qmail is still down)
# - if the authentication backend is not cdb, convert the remote auth data
# - start local POP3/IMAP daemons
# - start qmail on remote host
#
# The addition of domains and alias domains on the new host is handled through the
# sister script called 'migrateDomain_remote_add'
#
# For more comfort during the migration of your domains, use public key
# authentication with ssh, so you don't have to enter the root password over and over.
#
# ATTENTION ATTENTION ATTENTION ATTENTION ATTENTION ATTENTION ATTENTION ATTENTION
#
# This script does NOT properly handle domains with hashed directories. For those
# domains, I'd manually add them on the new server, edit /var/qmail/users/assign
# to use the new path, run qmail-newu, and move the domain directory into the
# hashed directory before starting the migrateDomain script on the old server.  When
# the old script calls migrateDomain_remote_add on the new server, which runs
# vadddomain, vadddomain would fail but the rest of the process would proceed
# correctly (I think).
#
#
# Heavily based on scripts provided by Tom Collins. Many thanx!
#
# Author: Paul Kremer, 2005 (biz dot spurious at paul, reverse!)
# Copyright: BSD Artistic License


# Configuration:
QD=/var/qmail # qmail installation dir
VPOPMAILDIR=/home/vpopmail
OLDDOMAINTRASH=/home/olddomains/

###################### MAIN ###############################
if [ $# -lt 3 ]; then
	echo "Usage: `basename $0` vauth-backend newhost virtualdomain [aliasdomains]" >&2
	echo "	vauth-backends supported: cdb|mysql"
	exit 1
fi

backend=$1
shift
newhost=$1
shift
domain=$1
shift
aliasdomains="$@"

domdir=`$VPOPMAILDIR/bin/vdominfo -d $domain`
if [ "$domdir" == "does not exist" ]
then
	echo "can't find email for $domain, are we really hosting it?"
	echo "(press return to continue)"
	read dummy
	exit
fi

if [ ! -d $domdir ]
then
	echo "Couldn't find mail for $domain."
	exit
fi

target=`echo "$domdir" | sed "s/$domain//"`
echo "Sync $domdir to $newhost:$target? [y/n]"
echo "Don't do this if it has a 0, because we can't handle it yet."
read answer

if [ "$answer" != "y" ]
then
	echo "Quitting"
	exit
fi

if [ $backend == "mysql" ];
then
	echo "Converting local authentication data to cdb for migration"
	$VPOPMAILDIR/bin/vconvert -m -c $domain
fi
echo "Doing initial rsync"
rsync -Pavz --delete -e ssh $domdir $newhost:$target

echo "stopping qmail on $newhost and adding $domain"
ssh root@$newhost /root/migrateDomain_remote_add $domain $aliasdomains

# stop vpopmail so nobody can pick up their email.
vpopmailctl stop

for dom in $domain $aliasdomains
do
	# remove from virtualdomains
	grep -v "$dom:$dom" $QD/control/virtualdomains > /tmp/vd
	cat /tmp/vd > $QD/control/virtualdomains

	# add to smtproutes
	echo "$dom:$newhost" >> $QD/control/smtproutes
done

# restart qmail so it will start forwarding
# ($newhost's qmail is down until we finish sync)
qmailctl restart

echo "Doing final rsync"
rsync -Pavz --delete -e ssh $domdir $newhost:$target
if [ $backend == "mysql" ];
then
	echo "Converting authentication data on $newhost to $backend"
	ssh root@$newhost $VPOPMAILDIR/bin/vconvert -c -m $domain
fi

if [ -d $OLDDOMAINTRASH ];
then
	mv $domdir $OLDDOMAINTRASH/$domain
else
	echo "Not moving $domdir to $OLDDOMAINTRASH: it does not exist!" >&2
fi

vpopmailctl start

echo "restarting qmail on $newhost"
ssh root@$newhost /usr/bin/qmailctl start
