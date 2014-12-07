#!/bin/bash

# kill existing processes first
killall flashback
killall flashback-leds.sh

# make sure no one mis-reads the stale status files
echo 'NOT STARTED' > /var/lib/flashback/queue
echo 'NOT STARTED' > /var/lib/flashback/status

# start the helper scripts
/root/flashback-leds.sh &
/root/usbhdd-keepalive.sh &

# wait for the external disk to be mounted
while [[ $(mount | grep -c "/backup") -eq 0 ]] ; do
   sleep 1
done

# wait for NTP sync, then start ntpd
systemctl stop ntpd
while [[ $(date +%Y) -lt 2014 ]] ; do
   ntpdate 172.31.1.1 || ntpdate pool.ntp.org
   sleep 1
done
systemctl start ntpd

# finally, run flashback
/usr/sbin/flashback -d 2>&1 > /backup/flashback.out &

# it should run forever, we never get here
exit 0

