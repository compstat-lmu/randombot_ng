#!/bin/bash
# This is the entry point!
# Sets up some variables, performs some tests, and calls sbatch the required
# number of times.

if [ -z "$2" ] ; then
    echo "Usage: $0 STARTSEED DRAINPROCS" >&2
    exit 1
fi

export STARTSEED="$1"
export DRAINPROCS="$2"

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

check_env ONEOFF STARTSEED STRESSTEST DRAINPROCS

sbatch --export=MUC_R_HOME,ONEOFF,STARTSEED,STRESSTEST \
       "$@" "${MUC_R_HOME}/scheduling/sbatch.cmd"

