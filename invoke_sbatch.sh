#!/bin/bash

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
export MUC_R_HOME="$(cd -P "$(dirname "$path")" >/dev/null 2>&1 && pwd)"


if ! [[ "${SCHEDULING_MODE}" =~ ^per(seed|param|cpu)$ ]] ; then
    echo "No valid SCHEDULING_MODE: $SCHEDULING_MODE"
    exit 2
fi

if ! [ -d "$BASEDIR" ] ; then
    echo "BASEDIR Not a directory: $BASEDIR"
    exit 4
fi

if [ -z "${USE_PARALLEL}" ] ; then
    export USE_PARALLEL=TRUE
fi
if ! [[ "${USE_PARALLEL}" =~ ^(TRUE|FALSE)$ ]] ; then
    echo "No valid USE_PARALLEL: $USE_PARALLEL"
    exit 5
fi

if [ -z "$INDEXSTEPSIZE" ] ; then
    export INDEXSTEPSIZE=20
fi
if ! [ "$INDEXSTEPSIZE" -gt 0 ] 2>/dev/null ; then
    echo "No valid INDEXSTEPSIZE: $INDEXSTEPSIZE"
    exit 1
fi


for ((i=0;i<"$INDEXSTEPSIZE";i++)) ; do
    sbatch "${MUC_R_HOME}/sbatch.cmd" --export=BASEDIR,MUC_R_HOME,SCHEDULING_MODE,USE_PARALLEL,INDEXSTEPSIZE,SBATCH_INDEX=${i} "$@"
done
