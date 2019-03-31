#!/bin/bash

# drain redis with as a manual shellscript-call.
# This still needs REDISHOST, REDISPORT and REDISPW
# set, but other things are set up to make the
# drainredis.R call more convenient.

if [ -z "$1" ] ; then
    echo "Usage: $0 DRAINPROCS" >&2
    exit 1
fi
export DRAINPROCS="$1"

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

check_env REDISHOST REDISPORT REDISPW DRAINPROCS

export SLURMD_NODENAME=manual
export SLURM_NPROCS="$DRAINPROCS"

export SLURM_PROCID

trap "exit" INT TERM
trap "kill 0" EXIT

for ((SLURM_PROCID=0;SLURM_PROCID<"$DRAINPROCS";SLURM_PROCID++)) ; do
    "${MUC_R_HOME}/scheduling/drainredis.R" NOBLOCK &
done

wait
