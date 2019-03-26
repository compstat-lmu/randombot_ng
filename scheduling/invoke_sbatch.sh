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

[ -z "$JOBCOUNT" ] && export JOBCOUNT=1
if [ -z "$REDISHOST" ] ; then
    export REDISHOST="$(cat REDISINFO | cut -d : -f 1)"
    export REDISPORT="$(cat REDISINFO | cut -d : -f 2)"
    export REDISPW="$(cat REDISINFO | cut -d : -f 3-)"
fi

check_env JOBCOUNT ONEOFF REDISHOST REDISPORT REDISPW

for ((i=0;i<"$JOBCOUNT";i++)) ; do
    sbatch --export=MUC_R_HOME,JOBCOUNT,ONEOFF,REDISHOST,REDISPORT,REDISPW \
	   "$@" "${MUC_R_HOME}/scheduling/sbatch.cmd"
done
