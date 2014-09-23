#!/bin/sh
# $Id: m_procs_unfinished 282 2006-06-06 12:15:37Z pkremer $

# config section
admin_mail="admin@example.com" # default mail address for notify
hostname=`hostname`
# end config section

# monitors process list for zombies, uninterruptible sleeps, and traced or stopped processes.

# loop forever
while true
do
   #query processes:
   problem_procs=`ps -eo state,pid,ppid,time,cmd | awk '/^Z|^D|^T/'`
   if [ "X${problem_procs}" != "X" ];
   then
      echo "Problematic processes found (either state Z|D|T)"
      echo "$problem_procs"
   fi

   # recheck every minute
   sleep 61
done


