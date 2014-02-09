#!/bin/bash

# test if apache is alive and eventually try to restart it!

# temp dir:
DIR="/home/admin/apachecheck/"
# URL to use for checking if apache is alive:
URL="http://localhost/server-status"
# email for restart notification:
adminemail="admin@example.com"

if [ ! -d $DIR ]; then
   echo "$DIR does not exist. please fix." | mail -s "[`hostname`] $0 problem" $adminemail
  exit 0
fi

if (wget $URL --spider -t 1 -T 30 >& /dev/null) ; then
  # apache is alive
  mv -f $DIR/current $DIR/last > /dev/null 2>&1
  lynx -connect_timeout=30 -dump $URL > $DIR/current 2>&1
else
  # apache is dead
  suffix=`eval date +%s`
  touch $DIR/apachecheck_${suffix}
  chmod 600 $DIR/apachecheck_${suffix}
  /etc/init.d/apache stop > $DIR/apachecheck_${suffix} 2>&1
  /etc/init.d/apache start >> $DIR/apachecheck_${suffix} 2>&1
  echo "LAST ------------------------" >> $DIR/apachecheck_${suffix}
  cat $DIR/last >> $DIR/apachecheck_${suffix}
  echo "CURRENT ------------------------" >> $DIR/apachecheck_${suffix}
  cat $DIR/current >> $DIR/apachecheck_${suffix}
  cat $DIR/apachecheck_${suffix} | mail -s "[`hostname`] $0 apache down" $adminemail
  rm -f $DIR/apachecheck_${suffix}
fi
