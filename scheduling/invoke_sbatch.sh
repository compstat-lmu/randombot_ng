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

check_env JOBCOUNT ONEOFF

for ((i=0;i<"$JOBCOUNT";i++)) ; do
    sbatch --export=MUC_R_HOME "$@" "${MUC_R_HOME}/scheduling/sbatch.cmd"
done
