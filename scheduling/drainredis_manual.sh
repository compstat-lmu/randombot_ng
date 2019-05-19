#!/bin/bash

# drain redis with as a manual shellscript-call.
# This still needs REDISHOST, REDISPORT and REDISPW
# set, but other things are set up to make the
# drainredis.R call more convenient.

trap "exit" INT TERM
trap "kill 0" EXIT


export DRAINPROCS=1
export REDISPORT=6379


NOMINUS=()

while [ "$#" -gt 0 ] ; do
    if [ "$1" = "--redisport" ] ; then
	REDISPORT="$2"
	shift
    elif [ "$1" = "--drainprocs" ] ; then
	DRAINPROCS="$2"
	shift
    else
	NOMINUS+=("$1")
    fi
    shift
done
set -- "${NOMINUS[@]}"

if ! [ -z "$1" ] ; then
    echo "Usage: $0 [--redisport PORT] [--drainprocs PROCS]" >&2
    exit 1
fi

if [[ "$DRAINPROCS" = *N ]] ; then
    # this may seem ad-hoc, but the normal check for DRAINPROCS accepts
    # a number of nodes, e.g. 2N, instead of number of drain processes.
    echo "DRAINPROCS must not end with N." >&2
    exit 2
fi

# get parent directory
path="${BASH_SOURCE[0]}"
while [ -h "$path" ] ; do
    linkpath="$(readlink "$path")"
    if [[ "$linkpath" != /* ]] ; then
	path="$(dirname "$path")/$linkpath"
    else
	path="$linkpath"
    fi
done
export MUC_R_HOME="$(cd -P "$(dirname "$path")/.." >/dev/null 2>&1 && pwd)"

. "$MUC_R_HOME/scheduling/common.sh"

export SLURMD_NODENAME="$(hostname)"

export REDISPW="$(head -c 128 /dev/urandom | sha1sum -b - | cut -c -40)"

check_env REDISPORT REDISPW DRAINPROCS

for SHARDDIR in REDIS/REDISINSTANCE_* ; do
    export CURSHARD="$(echo "$SHARDDIR" | sed 's|REDIS/REDISINSTANCE_||')"
    export SHARDS="$((CURSHARD+1))"
    check_env CURSHARD SHARDS
    echo "Starting Redis for shard $CURSHARD in directory $SHARDDIR"
    if [ -f "REDISINFO_${CURSHARD}" ] ; then rm "REDISINFO_${CURSHARD}" || exit 102 ; fi
    "$MUC_R_HOME/scheduling/runredis.sh" 2>&1 | \
	sed -u "s'^'[REDIS]: '" | \
	grep --line-buffered '^' &
    while ! [ -f "REDISINFO_${CURSHARD}" ] ; do sleep 1 ; done
    export REDISHOST="$(cat "REDISINFO_${CURSHARD}" | cut -d : -f 1)"
    export REDISPORT="$(cat "REDISINFO_${CURSHARD}" | cut -d : -f 2)"
    export REDISPW="$(cat "REDISINFO_${CURSHARD}" | cut -d : -f 3-)"
    echo "[MAIN]: Redis running on host $REDISHOST port $REDISPORT password $REDISPW"
    check_env REDISHOST REDISPORT REDISPW
    
    echo "Trying to connect to redis..."
    setup_redis  # common.sh
    echo "Redis is up."
    
    SLURMD_NODENAME=manual
    export SLURM_NPROCS="$DRAINPROCS"
    
    export SLURM_PROCID
    
    
    for ((SLURM_PROCID=0;SLURM_PROCID<"$DRAINPROCS";SLURM_PROCID++)) ; do
	"${MUC_R_HOME}/scheduling/drainredis.R" NOBLOCK &
    done
    
    wait
done
