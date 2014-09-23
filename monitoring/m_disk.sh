#!/bin/ksh
# $Id: m_disk 282 2006-06-06 12:15:37Z pkremer $

# config section
admin_mail="admin@example.com" # default mail address for notify
hostname=`hostname`
disk_notify_treshold=75
disk_alarm_treshold=90
# end config section

typeset -RZ4 usage_with_percent_sign

while true
do
   df -P | tail +2 | while read foo
   do
      usage_with_percent_sign=$(echo $foo | awk '{print $5}')
      usage=${usage_with_percent_sign%%%}
      fs=$(echo $foo | awk '{print $1}')
      mount=$(echo $foo | awk '{print $6}')
      if (( usage > disk_notify_treshold )) ; then
         df -P | mail -s "File system $fs mounted at $mount is $usage % full on host $hostname" $admin_mail
      fi
      if (( usage > disk_alarm_treshold )) ; then
         df -P | mail -s "File system $fs mounted at $mount is $usage % full on host $hostname" $admin_mail
      fi
   done
   sleep 28802 # 8 hours
done
