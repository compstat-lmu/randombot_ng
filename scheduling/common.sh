#!/bin/bash

# define functions used by all scripts

check_env() {
    if [ "$#" -eq 0 ] ; then
	echo "bad check_env call" >&2
	exit 254
    fi

    for WHAT in "$@" ; do
	case "$WHAT" in
	    STARTSEED)
		if [ -z "${STARTSEED}" ] || \
		       ! [ "$STARTSEED" -ge 0 ] 2>/dev/null ; then
		    echo "No valid STARTSEED: $STARTSEED"
		    exit 2
		fi
		;;
	    DATADIR)
		if ! [ -d "$DATADIR" ] ; then
		    echo "Inferred DATADIR Not a directory: $DATADIR"
		    exit 8
		fi
		;;
	    REDISHOST)
		if [ -z "$REDISHOST" ] ; then
		    echo "REDISHOST not given" >&2
		    exit 13
		fi
		;;
	    REDISPORT)
		if ! [ "$REDISPORT" -gt 0 ] ; then
		    echo "REDISPORT not valid: $REDISPORT" >&2
		    exit 14
		fi
		;;
	    REDISPW)
		if [ -z "$REDISPW" ] ; then
		    echo "Missing REDISPW" >&2
		    exit 16
		fi
		;;
	    ONEOFF)
		if ! [ -z "$ONEOFF" ] && \
			! [ "$ONEOFF" == TRUE -o "$ONEOFF" == FALSE ] ; then
		    echo "ONEOFF not valid: $ONEOFF" >&2
		    exit 15
		fi
		;;
	    STRESSTEST)
		if ! [ -z "$STRESSTEST" ] && \
			! [ "$STRESSTEST" == TRUE -o "$STRESSTEST" == FALSE ] ; then
		    echo "STRESSTEST not valid: $STRESSTEST" >&2
		    exit 15
		fi
		;;
	    SHARDS)
		if ! [ "$SHARDS" -gt 0 ] ; then
		    echo "SHARDS not valid: $SHARDS" >&2
		    exit 14
		fi
		;;
	    CURSHARD)
		if ! [ "$CURSHARD" -ge 0 -a "$CURSHARD" -lt "$SHARDS" ] ; then
		    echo "CURSHARD not valid: $CURSHARD\nSHARDS: $SHARDS" >&2
		    exit 15
		fi
		;;
	    REDISHOSTLIST)
		if [ -z "$REDISHOSTLIST" ] || \
		       [ "$(echo "$REDISHOSTLIST" | wc -l)" -ne "$SHARDS" ] ; then
		    echo "Invalid REDISHOSTLIST:" >&2
		    echo "$REDISHOSTLIST" >&2
		    exit 16
		fi
		;;
	    DRAINPROCS)
		if ! [ "$DRAINPROCS" -gt 0 ] ; then
		    echo "Invalid DRAINPROCS: $DRAINPROCS" >&2
		    exit 17
		fi
		;;
	    *)
		echo "bad check_env argument $WHAT" >&2
		exit 253
		;;
	esac
    done
}

setup_redis() {
    while [ "$connok" != "PONG" ] ; do
	sleep 1
	connok="$(Rscript -e 'cat(sprintf("auth %s\nping\n", Sys.getenv("REDISPW")))' | \
	  redis-cli -h "$REDISHOST" -p "$REDISPORT" 2>/dev/null | grep PONG)"		
    done
    
    buckok="$(Rscript -e 'cat(sprintf("auth %s\ndel BUCK\nlpush BUCK BUCK\nlpush BUCK BUCK\nlpush BUCK BUCK\nlpush BUCK BUCK\nlindex BUCK 0\n", Sys.getenv("REDISPW")))' | \
      redis-cli -h "$REDISHOST" -p "$REDISPORT" 2>/dev/null | grep -o BUCK)"   
    if [ "$buckok" != "BUCK" ] ; then
	echo "Error setting up redis" >&2
	exit 20
    fi
}
