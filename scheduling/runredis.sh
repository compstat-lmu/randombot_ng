#!/bin/bash
# This is the redis entrypoint!
# Sets up some variables, performs some tests, and calls sbatch 

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

check_env REDISPORT

sbatch --export=MUC_R_HOME,REDISPORT "$@" "${MUC_R_HOME}/scheduling/runredis_batchscript.cmd"
