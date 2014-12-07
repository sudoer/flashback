#!/bin/bash

# This script runs on a remote host, and accesses the
# flashback status via http.  It looks to see if things
# look "sane": the host is reachable, the status is there,
# it is recent (meaning flashback is still running), and
# the filesystem has some space left.

# Run this script via cron on some other host that is
# always up.  Pass in the flashback host's name and the
# disk percentage that you'd like to warn at.

host=$1
warnpct=$2

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
disk_total=$(grep "^disk.total.bytes=" $tmp | awk -F= '{print $2}')
disk_used=$(grep "^disk.used.bytes=" $tmp | awk -F= '{print $2}')
fullpct=$(( $disk_used * 100 / $disk_total ))
if [[ $fullpct -gt $warnpct ]] ; then
   echo "backup filesystem ($disk_mntpt) on $host is filling up ($fullpct%)"
   exit 4
fi
# clean up
rm $tmp
exit 0

