#!/bin/ksh
# $Id: m_memory 282 2006-06-06 12:15:37Z pkremer $

# config section
admin_mail="admin@example.com" # default mail address for notify
hostname=`hostname`
# freemem+cached+buffers has to be bigger than MIN_FREE
min_free=10000
# end config section

# monitors mem usage

count=0
# loop forever
while true
do
   MEMI="/proc/meminfo"
   #query /proc for mem info
   total_memory=$(awk '/^MemTotal/ {print $2}' $MEMI)
   total_swap=$(awk '/^SwapTotal/ {print $2}' $MEMI)
   free_memory=$(awk '/^MemFree/ {print $2}' $MEMI)
   free_swap=$(awk '/^SwapFree/ {print $2}' $MEMI)
   cached=$(awk '/^Cached/ {print $2}' $MEMI)
   buffers=$(awk '/^Buffers/ {print $2}' $MEMI)
   # if mem is low, advise but do not panic
   let real_free=$free_memory+$cached+$buffers
   #echo "free : $free_memory"
   #echo "cached : $cached"
   #echo "buffers : $buffers"
   #echo "real : $real_free"
   #if (( real_free < (total_memory / 10) ))
   if (( real_free < min_free ))
   then
      (( count += 1 ))
      if (( (count % 100) == 0 ))
      then
         cat /proc/meminfo | mail -s "Warning - Low memory - total:$total_memory - free:$free_memory" $admin_mail
      fi
   fi

   # if swap is low, tell it now
   if (( free_swap < (total_swap / 5) ))
   then
      cat /proc/meminfo | mail -s "Running low on swap" $admin_mail
   fi

   # recheck every minute
   sleep 61
done


