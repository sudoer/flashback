#!/bin/bash

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
   if [ $(cat /dev/null /proc/$pid/cmdline 2>/dev/null | grep -c 'flashback') -eq 0 ] ; then
      stat='DOWN'
   fi
   case $stat in
      'DOWN')
         # not working - three short red blips (think "SOS")
         led_red ; sleep 2 ; led_off
         ;;
      'BACKING_UP')
         # blink yellow twice quickly
         led_yellow ; sleep 0.2 ; led_off ; sleep 0.4
         led_yellow ; sleep 0.2 ; led_off ; sleep 0.4
         ;;
      'ROTATING'|'CLEANING')
         # blink yellow three times very quickly
         led_yellow ; sleep 0.1 ; led_off ; sleep 0.2
         led_yellow ; sleep 0.1 ; led_off ; sleep 0.2
         led_yellow ; sleep 0.1 ; led_off ; sleep 0.2
         ;;
      'IDLE')
         # blink yellow once if any backup succeeded
         if [[ $statusSuccess -gt 0 ]] ; then
            led_yellow ; sleep 0.3 ; led_off ; sleep 0.6
         fi
         # blink red once if any backup failed
         if [[ $statusErrs -gt 0 ]] ; then
            led_red ; sleep 0.3 ; led_off ; sleep 0.6
         fi
         # blink green once for each "wait" minute
         for x in $(seq 1 $wt) ; do
            led_green ; sleep 0.3 ; led_off ; sleep 0.3
         done
         ;;
   esac
   sleep 1
done


