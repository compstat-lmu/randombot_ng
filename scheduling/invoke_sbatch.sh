#!/bin/bash
# This is the entry point!
# Sets up some variables, performs some tests, and calls sbatch the required
# number of times.

export STARTSEED=0
export REDISPORT=6379
export DRAINPROCS=1N

NOMINUS=()

while [ "$#" -gt 0 ] ; do
    if [ "$1" = "--oneoff" ] ; then
	export ONEOFF=TRUE
    elif [ "$1" = "--stresstest" ] ; then
	export STRESSTEST=TRUE
    elif [ "$1" = "--startseed" ] ; then
	STARTSEED="$2"
	shift
    elif [ "$1" = "--redisport" ] ; then
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
set -- "${NOMINUS}"

# if ! [ -z "$1" ] ; then
#    echo "Usage: $0 [--oneoff] [--stresstest] [--startseed SEED] [--redisport PORT] [--drainprocs PROCS]" >&2
#    exit 1
# fi

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

check_env ONEOFF STARTSEED STRESSTEST DRAINPROCS REDISPORT

sbatch --export=MUC_R_HOME,ONEOFF,STARTSEED,STRESSTEST,DRAINPROCS,REDISPORT \
       "$@" "${MUC_R_HOME}/scheduling/sbatch.cmd"

