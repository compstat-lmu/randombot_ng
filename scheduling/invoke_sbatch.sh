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

[ -z "${USE_PARALLEL}" ] && export USE_PARALLEL=TRUE
[ -z "$INDEXSTEPSIZE" ] && export INDEXSTEPSIZE=20
[ -z "$CONTROL_JOB_COUNT" ] && export CONTROL_JOB_COUNT=1

check_env BASEDIR SCHEDULING_MODE USE_PARALLEL INDEXSTEPSIZE CONTROL_JOB_COUNT

for ((i=0;i<"$INDEXSTEPSIZE";i++)) ; do
    sbatch "${MUC_R_HOME}/scheduling/sbatch.cmd" \
	   --export=BASEDIR,MUC_R_HOME,SCHEDULING_MODE,USE_PARALLEL,INDEXSTEPSIZE,CONTROL_JOB_COUNT,SBATCH_INDEX=${i} \
	   "$@"
done
