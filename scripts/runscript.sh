#!/bin/bash
# run script, to be launched using `srun` in an sbatch command file
# Expectations:
# - This file is not copied somewhere else, but instead ran from its path
#   in the randombot_ng/scripts directory
# - start path is the base output directory, the same one 
# - command line is $0 <MODE> <TASKNAME> <LEARNERNAME> <PARAMS/SEED/STARTINDEX>
# - <MODE> one of percpu, perseed, perparam
# - if <MODE> is percpu, the PERCPU_STEPSIZE env var must be set

SCHEDULING_MODE="$1"
TASKNAME="$2"
LEARNERNAME="$3"
ARGUMENT="$4"

TOKEN="$((date +"%F_%T"))_${RANDOM}"

if [ -z "$ARGUMENT" ]; then
    echo "Bad Command line: $*" >&2
    exit 100
fi
if [ "$SCHEDULING_MODE" = percpu ] && ! [ "$PERCPU_STEPSIZE" -gt 0 ] ; then
    echo "Missing or invalid PERCPU_STEPSIZE: $PERCPU_STEPSIZE" >&2
    exit 101
fi

if ! [[ "${SCHEDULING_MODE}" =~ ^per(seed|param|cpu)$ ]] ; then
    echo "No valid SCHEDULING_MODE: $SCHEDULING_MODE"
    exit 102
fi

if ! [ -d "$MUC_R_HOME" ] ; then
    echo "MUC_R_HOME Not a directory: $MUC_R_HOME"
    exit 103
fi

if ! [ -d "$BASEDIR" ] ; then
    echo "BASEDIR Not a directory: $BASEDIR"
    exit 104
fi

cd -P "$(echo "$SLURMD_NODENAME" | md5sum | cut -c -2)/${SLURMD_NODENAME}/work" || \
    exit 105
NODEDIR="$(pwd)"
# NODEDIR: node-local directory, for file system reasons
export NODEDIR

# workdir: 
WORKDIR="${NODEDIR}/$(printf "%02d\n" "$((RANDOM%100))")/$(printf "%02d\n" "$((RANDOM%100))")"
mkdir -p "$WORKDIR"

# watchfile:
# delete old watchfiles first
comm -23 \
     <(ls WATCHFILE_* | sort) \
     <(ps -eo "%p" --no-headers | sed 's/^ */WATCHFILE_/' | sort) | \
    xargs rm
# create new watchfile
export WATCHFILE=WATCHFILE_$$
touch "$WATCHFILE"

if [ "$SCHEDULING_MODE" = percpu ] ; then
    TODO
else
    /usr/bin/time -f "----[$RANDOM] E %E K %Ss U %Us P %P M %MkB O %O" Rscript "$MUC_R_HOME/eval_single.R" &
    pid=$!
    "$MUC_R_HOME/scripts/watchdog.sh" $pid "$WATCHFILE"
    wait $pid
    result=$?
    echo "----[${TOKEN}] eval_single.R exited with status $result"
fi

exit $result
