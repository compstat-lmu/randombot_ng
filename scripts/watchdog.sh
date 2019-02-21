#!/bin/bash

killwatchpid() {
    kill "$watchpid" 2>/dev/null
    sleep "$1"
    kill -s KILL "$watchpid" 2>/dev/null
}

if [ -z "$2" ] ; then
    echo "Usage: $0 watchpid waitfile [initial timeout in integer seconds]" >&2
    exit 253
fi
if [ -z "$3" ] ; then
    initto=120
else
    initto="$3"
fi

watchpid=$1
WATCHFILE="$2"



trap 'killwatchpid 0.5' SIGINT SIGTERM EXIT
 
timeout=$(($(date +"%s") + initto))

while true ; do

    waittime=$((timeout - $(date +"%s")))

    if ! [ 0 -lt "$waittime" ] ; then # use '!' because we also want to exit if waittime is not integer
	echo "[${WATCHFILE}] Watchdog killing pid $watchpid, wau wau"
	killwatchpid 1
	exit 1
    fi

    sleep "$((waittime + 1))" 2>/dev/null &
    wait -n $! $watchpid

    if ! kill -0 $watchpid 2>/dev/null ; then
	echo "[${WATCHFILE}] Watchpid $watchpid is gone, exiting wau wau"
        trap "" EXIT
	exit 0
    fi
    echo "timed out"
    if [ -r "$WATCHFILE" ] ; then
	timeout="$(cat "$WATCHFILE")"
    else
	echo "[${WATCHFILE}] Watchfile not found, wau wau"
    fi
done
