#!/bin/bash
# run script, to be launched using `srun` in an sbatch command file
# Expectations:
# - This file is not copied somewhere else, but instead ran from its path
#   in the randombot_ng/scheduling directory
# - start path is BASEDIR
# - command line is $0 <MODE> <TASKNAME> <LEARNERNAME> <PARAMS/SEED/STARTINDEX>
# - <SCHEDULING_MODE> one of percpu, perseed, perparam
# - if <SCHEDULING_MODE> is percpu, the PERCPU_STEPSIZE env var must be set
# - if <SCHEDULING_MODE> is percpu, the PROGRESS env var must be set to a number
# - if <SCHEDULING_MODE> is percpu, the
#     BASEDIR/joblookup/<LEARNERNAME>/<TASKNAME>/PROGRESSPOINTER_<STARTINDEX>
#   is written to and contains the "progress file" path.

export SCHEDULING_MODE="$1"
export TASKNAME="$2"
export LEARNERNAME="$3"
export ARGUMENT="$4"

export TOKEN="$(date +"%F_%T")_${RANDOM}"

if [ -z "$ARGUMENT" ]; then
    echo "Bad Command line: $*" >&2
    exit 100
fi

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



check_env BASEDIR SCHEDULING_MODE PERCPU_STEPSIZE PROGRESS

cd -P "$BASEDIR/$(echo "$SLURMD_NODENAME" | md5sum | cut -c -2)/$SLURMD_NODENAME/work" || \
    exit 105
NODEDIR="$(pwd)"
# NODEDIR: node-local directory, for file system reasons
export NODEDIR

# workdir: 
WORKDIR="$NODEDIR/$(printf "%02d\n" "$((RANDOM%100))")/$(printf "%02d\n" "$((RANDOM%100))")"
mkdir -p "$WORKDIR"
export WORKDIR

# watchfile:
# delete old watchfiles first
comm -23 \
     <(find -maxdepth 1 -type f -name 'WATCHFILE_*' -printf '%f\n' | sort) \
     <(ps -eo "%p" --no-headers | sed 's/^ */WATCHFILE_/' | sort) | \
    xargs rm 2>/dev/null
# create new watchfile
export WATCHFILE=WATCHFILE_$$
touch "$WATCHFILE"

if [ "$SCHEDULING_MODE" = percpu ] ; then
    export PROGRESSFILE="${NODEDIR}/PROGRESSFILE_${ARGUMENT}"
    echo "$PROGRESS" > "$PROGRESSFILE"

    get_progresspointer "$ARGUMENT"
    echo "$PROGRESSFILE" > "$PROGRESSPOINTER"
    
    evalfile="eval_multiple.R"
else
    evalfile="eval_single.R"
fi

/usr/bin/time -f "----[$TOKEN] E %E K %Ss U %Us P %P M %MkB O %O" \
	      Rscript "$MUC_R_HOME/scheduling/${evalfile}" &
pid=$!
"${MUC_R_HOME}/scheduling/watchdog.sh" $pid "$WATCHFILE" &
wpd=$!
wait $pid
result=$?
kill "$wpd" 2>/dev/null
echo "----[${TOKEN}] ${evalfile} exited with status $result"

exit $result
