#!/bin/bash
host=sheeva
# ping
ping -q -c 1 $host > /dev/null
if [[ $? -ne 0 ]] ; then
   echo "host $host is not reachable"
   exit 1
fi
# get web status
tmp=/tmp/sheeva.status.$$
wget -q "http://$host/status.txt" -O $tmp
if [[ $? -ne 0 ]] ; then
   echo "can not get status from $host via http"
   exit 2
fi
# parse web status - time
# date=2012-12-30
# time=23:18:01
sheevadate=$(grep "^date=" $tmp | awk -F= '{print $2}')
sheevatime=$(grep "^time=" $tmp | awk -F= '{print $2}')
sheevasecs=$(date +%s -d "$sheevadate $sheevatime")
nowsecs=$(date +%s)
diff=$(( nowsecs < sheevasecs ? sheevasecs - nowsecs : nowsecs - sheevasecs ))
if [[ $diff -gt $((3600 * 12)) ]] ; then
   echo "backup status on $host has a funny timestamp ($sheevadate/$sheevatime)"
   exit 3
fi
# parse web status - fullness
disk_mntpt=$(grep "^disk.mntpt=" $tmp | awk -F= '{print $2}')
disk_total=$(grep "^disk.total=" $tmp | awk -F= '{print $2}')
disk_used=$(grep "^disk.used=" $tmp | awk -F= '{print $2}')
fullpct=$(( $disk_used * 100 / $disk_total ))
if [[ $fullpct -gt 66 ]] ; then
   echo "backup filesystem ($disk_mntpt) on $host is filling up ($fullpct%)"
   exit 4
fi
# clean up
rm $tmp
exit 0

