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

get_progressdir() {  # sets PROGRESSDIR
    if [ -z "$LEARNERNAME" -o -z "$TASKNAME" ] ; then
	echo "get_progressdir(): LEARNERNAME or TASKNAME missing." >&2
	exit 252
    fi
    PROGRESSDIR="${BASEDIR}/joblookup/${LEARNERNAME}/${TASKNAME}"
}

get_progresspointer() {  # sets PROGRESSDIR and PROGRESSPOINTER
    if [ -z "$1" ] ; then
	echo "Bad invocation of get_progressfile: need index." >&2
	exit 251
    fi
    get_progressdir
    local i="$1"
    PROGRESSPOINTER="${PROGRESSDIR}/PROGRESSPOINTER_${i}"
}

get_progress_from_pointer() {  # sets PROGRESS
    if [ -z "$1" ] ; then
	echo "Bad invocation of get_progress_from_pointer: need index." >&2
	exit 251
    fi
    get_progresspointer "$1"
    PROGRESSSOURCE="${BASEDIR}/joblookup/${LEARNERNAME}/${TASKNAME}"
    NEWPF="${PROGRESSDIR}/PROGRESSFILE_${i}"
    if [ -f "$NEWPF" ] ; then
	PROGRESS="$(cat "$NEWPF")"
    fi
    if ! [ "$PROGRESS" -ge 0 ] 2>/dev/null ; then
	PROGRESS="$1"
    fi
    if [ -f "$PROGRESSPOINTER" ] ; then
	OLDPF="$(cat "$PROGRESSPOINTER")"
	if mv -f "$OLDPF" "${NEWPF}.tmp" ; then
	    for ((i=0;i<180;i++)) ; do
		if [ -f "${NEWPF}.tmp" ] ; then break ; fi
		sleep 1
	    done
	fi
	NEWPROGRESS="$(cat "${NEWPF}.tmp")"

	if ! [ "$NEWPROGRESS" -ge "$PROGRESS" ] 2>/dev/null ; then
	    rm -f "${NEWPF}.tmp"
	else
	    mv -f "${NEWPF}.tmp" "$NEWPF"
	    PROGRESS="$NEWPROGRESS"
	fi
    fi
}
