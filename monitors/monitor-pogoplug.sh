#!/bin/bash

# This script was designed to run on a Pogo Plug 4.
# It reads the status of the flashback backup program,
# and it blinks the Pogo LED accordingly.

status_file="/var/lib/flashback/status"
queue_file="/var/lib/flashback/queue"

function led_red () {
   echo "none" > /sys/class/leds/status\:green\:health/trigger
   echo "default-on" > /sys/class/leds/status\:red\:fault/trigger
}

function led_yellow () {
   echo "default-on" > /sys/class/leds/status\:green\:health/trigger
   echo "default-on" > /sys/class/leds/status\:red\:fault/trigger
}

function led_green () {
   echo "default-on" > /sys/class/leds/status\:green\:health/trigger
   echo "none" > /sys/class/leds/status\:red\:fault/trigger
}

function led_off () {
   echo "none" > /sys/class/leds/status\:green\:health/trigger
   echo "none" > /sys/class/leds/status\:red\:fault/trigger
}

led_off

while true ; do
   statusFile=$(mktemp)
   cp $status_file $statusFile
   queueFile=$(mktemp)
   cp $queue_file $queueFile
   pid=$(grep '^pid=' $statusFile | awk -F= '{print $2}')
   stat=$(grep '^status=' $statusFile | awk -F= '{print $2}')
   wt=$(grep '^wait=' $statusFile | awk -F= '{print $2}')
   statusErrs=$(grep -c 'FAILED' $queueFile)
   statusSuccess=$(grep -c 'SUCCEEDED' $queueFile)
   rm $statusFile
   rm $queueFile
   if [ $(cat /dev/null /proc/$pid/cmdline 2>/dev/null | grep -c 'flashback') -eq 0 ] ; then
      stat='DOWN'
   fi
   case $stat in
      'DOWN')
         # long red = we're dead
         led_red ; sleep 2 ; led_off ; sleep 1
         ;;
      'BACKING_UP')
         # alternate yellow and green (more yellow than green)
         led_yellow ; sleep 1.25 ; led_green ; sleep 0.5
         ;;
      'ROTATING'|'CLEANING')
         # alternate green and yellow (more green than yellow)
         led_green ; sleep 1.25 ; led_yellow ; sleep 0.5
         ;;
      'IDLE')
         # one short yellow if any backup succeeded
         if [[ $statusSuccess -gt 0 ]] ; then
            led_yellow ; sleep 0.3 ; led_off ; sleep 0.6
         fi
         # one short red if any backup failed
         if [[ $statusErrs -gt 0 ]] ; then
            led_red ; sleep 0.3 ; led_off ; sleep 0.6
         fi
         # one short green for each minute of "waiting"
         for x in $(seq 1 $wt) ; do
            led_green ; sleep 0.3 ; led_off ; sleep 0.3
         done
         sleep 1
         ;;
   esac
done


