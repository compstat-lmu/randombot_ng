#!/bin/bash

if [ -z "$2" ] || ! [ "$2" -gt 0 ] 2>/dev/null ; then
    echo "Usage: $0 BASEDIR FILE" >&2
    echo "$0: create working directories on supermuc, of the shape BASEDIR/xx/nodename/work/ for =nodename= read from file FILE ('-' for stdin), and =xx= being the first two characters of =md5sum nodename=" >&2
    echo "The .../work/ directory can be used node-locally, but if many files are going to be written, the .../work/kk/ folders should be used." >&2
    exit 1
fi

BASEDIR="$1"

if [[ "$BASEDIR" == *"|"* ]] ; then
    echo "Illegal '|' character in BASEDIR." >&2
    exit 2
fi

if ! [ -d "$BASEDIR" ] ; then
    echo "BASEDIR $BASEDIR is not a directory." >&2
    exit 3
fi

cat "$2" | while read NODENAME ; do
    echo -n "$(echo "$NODENAME" | md5sum | cut -c -2)/${NODENAME}/work\0"
done | xargs -0 mkdir -p 
	
    
