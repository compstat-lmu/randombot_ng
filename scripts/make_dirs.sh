#!/bin/bash

if [ -z "$2" ] || ! [ "$2" -gt 0 ] 2>/dev/null ; then
    echo "$0: create working directories on supermuc, of the shape BASEDIR/xx/xx/xx/work/kk/ for node number xxxxxx ranging from 000000 to max-node-nr, and for kk ranging from 00 to 99." >&2
    echo "The .../work/ directory can be used node-locally, but if many files are going to be written, the .../work/kk/ folders should be used." >&2
    echo "Usage: $0 BASEDIR max-node-nr" >&2
    exit 1
fi

BASEDIR="$1"
MAXNODE="$(($2 * 100 - 1))"

if [[ "$BASEDIR" == *"|"* ]] ; then
    echo "Illegal '|' character in BASEDIR." >&2
    exit 2
fi

if ! [ -d "$BASEDIR" ] ; then
    echo "BASEDIR $BASEDIR is not a directory." >&2
    exit 3
fi



seq -f "%08.0f" 0 "$MAXNODE" | \
    sed "s|\\(.*\\)\\(..\\)\\(..\\)\\(..\\)\$|${BASEDIR}/\\1/\\2/\\3/work/\\4|" | \
    xargs mkdir -p
    
	
    
