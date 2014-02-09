#!/bin/sh
MAILTO="admin@example.com"
cd /var/qmail
messdirs=`echo queue/mess/* | wc -w`
messfiles=`find queue/mess/* -print | wc -w`
tododirs=`echo queue/todo | wc -w`
todofiles=`find queue/todo -print | wc -w`
qmess=`expr $messfiles - $messdirs`
qtodo=`expr $todofiles - $tododirs`

if [[ $qmess -gt 100 || $qtodo -gt 10 ]];
then
MESSAGE="
The Qmail queue on host `hostname` seems to grow too big:

messages in queue: $qmess
messages in queue but not yet preprocessed: $qtodo"
fi
if [ "$MESSAGE" != "" ]; then
   echo "$MESSAGE" |/usr/bin/mail -s "${0}" "$MAILTO"
fi
