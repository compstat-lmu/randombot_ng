#!/bin/bash
# This is the entry point!
# Sets up some variables, performs some tests, and calls sbatch the required
# number of times.

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


export STARTSEED=0
export REDISPORT=6379
export SHARDS=1
if [ -e SHARDS ] ; then
    SHARDS="$(cat SHARDS)"
    check_env SHARDS
fi

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
    elif [ "$1" = "--shards" ] ; then
	SHARDS="$2"
	shift
    else
	NOMINUS+=("$1")
    fi
    shift
done
set -- "${NOMINUS[@]}"

# if ! [ -z "$1" ] ; then
#    echo "Usage: $0 [--oneoff] [--stresstest] [--startseed SEED] [--redisport PORT] [--shards SHARDS]" >&2
#    exit 1
# fi

check_env ONEOFF STARTSEED STRESSTEST SHARDS REDISPORT

if [ -e SHARDS ] ; then
    OLDSHARDS="$(cat SHARDS)"
    if ! [ "${OLDSHARDS}" -ne "${SHARDS}" ] ; then
	echo "Found previous number of shards $PREVSHARDS unequal to requested number of shards $SHARDS. Exiting." >&2
	exit 31
    fi
fi
echo "$SHARDS" > SHARDS

sbatch --export=MUC_R_HOME,ONEOFF,STARTSEED,STRESSTEST,SHARDS,REDISPORT \
       "$@" "${MUC_R_HOME}/scheduling/sbatch.cmd"

