#!/bin/ksh
# $Id: m_cpu 282 2006-06-06 12:15:37Z pkremer $

# config section
admin_mail="admin@example.com" # default mail address for notify
cpu_treshold=60
hostname=`hostname`
# end config section

count=0
# loop forever
while true
do
   # top cpu processes
   foo=$(ps -eo pid,%cpu,command --sort %cpu | tail -n 1)
   current_top_cpu=$(print $foo | awk '{print $2}')
   current_top_cpu=${current_top_cpu%%.*}
   current_top_pid=$(print $foo | awk '{print $1}')

   # if top cpu is over the limit, keep track
   if (( $current_top_cpu > cpu_treshold ))
   then
      # if top cpu is the same as last time, count it
      if (( current_top_pid == bad_pid  ))
      then
         (( count += 1 ))
         # if top cpu has been on top an even multiple of 5 cycles
         # we alert
         if (( (count % 5) == 0 ))
         then
            ps auxwww | mail -s "Process $bad_pid over $cpu_treshold % CPU treshold on host $hostname" $admin_mail
         fi
      else
         bad_pid=$current_top_pid
         count=0
      fi
   else
      count=0     
   fi
   # cycle every minute
   sleep 60
done

