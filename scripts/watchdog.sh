#!/bin/bash

killchild() {
    kill "$child" 2>/dev/null
    sleep "$1"
    kill -s KILL "$child" 2>/dev/null
}

if [ -z "$2" ] ; then
    echo "Usage: $0 rfile waitfile [initial timeout in integer seconds]" >&2
    exit 253
fi
if [ -z "$3" ] ; then
    initto=120
else
    initto="$3"
fi

export WATCHFILE="$2"

Rscript "$1" &

child=$!

trap 'killchild 0.5' SIGINT SIGTERM EXIT
 
timeout=$(($(date +"%s") + initto))

while true ; do

    waittime=$((timeout - $(date +"%s")))

    echo "timeout $timeout waittime $waittime"

    if ! [ 0 -lt "$waittime" ] ; then # use '!' because we also want to exit if waittime is not integer
	echo "killing child, wau wau"
	killchild 1
	exit 1
    fi

    sleep "$((waittime + 1))" 2>/dev/null &
    wait -n $! $child

    if ! kill -0 $child 2>/dev/null ; then
	echo "child is gone"
        trap "" EXIT
	exit 0
    fi
    echo "timed out"
    if [ -r "$WATCHFILE" ] ; then
	timeout="$(cat "$WATCHFILE")"
    else
	echo "no waitfile !?"
    fi
done
