#!/bin/bash

status_file="/var/lib/flashback/status"

function led_on () {
   echo "default-on" > /sys/class/leds/plug\:green\:health/trigger
}

function led_off () {
   echo "none" > /sys/class/leds/plug\:green\:health/trigger
}

function led_blink () {
   count=$1
   on=$2
   off=$3
   for i in $(seq 1 $count) ; do
      echo "default-on" > /sys/class/leds/plug\:green\:health/trigger
      sleep $on
      echo "none" > /sys/class/leds/plug\:green\:health/trigger
      sleep $off
   done
}

led_off

while true ; do
   tmp=$(mktemp)
   cp $status_file $tmp
   pid=$(grep '^pid=' $tmp | awk -F= '{print $2}')
   stat=$(grep '^status=' $tmp | awk -F= '{print $2}')
   rm $tmp
   if [ $(cat /dev/null /proc/$pid/cmdline 2>/dev/null | grep -c 'flashback') -eq 0 ] ; then
      stat='down'
   fi
   case $stat in
      'down')
         # not working - three short blips (think "SOS")
         led_blink 3 0.1 0.3
         sleep 2
         ;;
      'backup')
         # blink very quickly
         led_blink 2 0.2 0.4
         ;;
      'rotate')
         # blink very quickly
         led_blink 2 0.1 0.2
         ;;
      'idle')
         # blink very slowly
         led_blink 5 2 1
         ;;
   esac
   sleep 2
done


