#!/bin/bash

# define functions used by all scripts

check_env() {
    if [ "$#" -eq 0 ] ; then
	echo "bad check_env call" >&2
	exit 254
    fi

    for WHAT in "$@" ; do
	case "$WHAT" in
	    JOBCOUNT)
		if [ -z "${JOBCOUNT}" ] || \
		       ! [ "$JOBCOUNT" -gt 0 ] 2>/dev/null ; then
		    echo "No valid JOBCOUNT: $JOBCOUNT"
		    exit 1
		fi
		;;
	    DATADIR)
		if ! [ -d "$DATADIR" ] ; then
		    echo "Inferred DATADIR Not a directory: $DATADIR"
		    exit 8
		fi
		;;
	    REDISHOST)
		if [ "$SCHEDULING_MODE" = redis ] && [ -z "$REDISHOST" ] ; then
		    echo "REDISHOST not given" >&2
		    exit 13
		fi
		;;
	    REDISPORT)
		if [ "$SCHEDULING_MODE" = redis ] && ! [ "$REDISPORT" -gt 0 ] ; then
		    echo "REDISPORT not valid: $REDISPORT" >&2
		    exit 14
		fi
		;;
	    ONEOFF)
		if ! [ -z "$ONEOFF" ] && \
			! [ "$ONEOFF" == TRUE -o "$ONEOFF" == FALSE ] ; then
		    echo "ONEOFF not valid: $ONEOFF" >&2
		    exit 15
		fi
		;;
	    *)
		echo "bad check_env argument $WHAT" >&2
		exit 253
		;;
	esac
    done
}

