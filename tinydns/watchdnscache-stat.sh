#!/bin/sh
SVCDIR="/service/dnscache"     # daemontools service directory
MULTILOG="log/main/current"    # subdir with log
MAILTO="admin@example.com"
MAILTO_TRESHOLD="1"
LOGFILE="/var/log/dnscache-stat.log"

if [ ! -e "$SVCDIR/motion" ]; then
   echo "1" > "$SVCDIR/motion"
fi

OLDMOTION=`/usr/bin/tail -n 1 "$SVCDIR/motion"`

MOTION=""
while [ "$MOTION" == "" ];
do
   MOTION=`/bin/grep stats "${SVCDIR}/${MULTILOG}" | /usr/bin/tail -n 1 | /usr/bin/cut -f 3 -d " "`
   sleep 1
done

echo "$MOTION" > "$SVCDIR/motion"

let diff=$MOTION-$OLDMOTION

CACHESIZE=`cat $SVCDIR/env/CACHESIZE`

SENDMAIL="0"
MESSAGE="Date : `date +%d-%m-%Y`
Cache motion since last run: $diff"

if [ $diff == 0 ]; then
   MESSAGE="$MESSAGE
difference undetermined, no cycle time available"
SENDMAIL="1"
else
   let res=$CACHESIZE/$diff
   MESSAGE="$MESSAGE
CACHESIZE / ( cache_motion ) = $res"

if [ $res -ge 10 ];
then
   MESSAGE="$MESSAGE
The cache cycle time is over a week. This leaves ample room for growth; the maximum common TTL is 3 days. dnscache won't save records for more than a week in any case."
fi
if [ $res -ge 1 ] && [ $res -lt 10 ];
then
   MESSAGE="$MESSAGE
The cache cycle time is roughly 1 day. There's still some benefit to a larger cache."
fi
let "test = res * 10"
if [ $test -ge 1 ] && [ $test -lt 10 ];
then
   MESSAGE="$MESSAGE
The cache cycle time is roughly 2 hours. This is above the AOL address TTL, but it's below the TTL of most records."
   SENDMAIL="1"
fi
let "test = res * 10"
if [ $test -lt 1 ];
then
   MESSAGE="$MESSAGE
The cache cycle time is roughly 15 minutes. Almost all DNS records have larger TTL (``time to live'') settings; they could be cached longer if the cache were larger."
   SENDMAIL="1"
fi

fi

echo "${MESSAGE}" >> "$LOGFILE"

if [ "x$SENDMAIL" == "x1" ]; then
   echo "$MESSAGE" |/usr/bin/mail -s "${0}" "$MAILTO"
fi

