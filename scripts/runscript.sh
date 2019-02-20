#!/bin/bash
# run script, to be launched using `srun` in an sbatch command file
# Expectations:
# - This file is not copied somewhere else, but instead ran from its path
#   in the randombot_ng/scripts directory
# - start path is the base output directory, the same one 
# - command line is $0 <MODE> <TASKNAME> <LEARNERNAME> <PARAMS/RUNID (if single)>
#   - mode: one of 'watchdog' or 'single'

if [ "$1" = "watchdog" ] ; then
    export SCHEDULING_MODE=watchdog
    if ! [ -z "$4" ] ; then
	echo "Scheduling mode watchdog only should have three arguments"
       
elif [ "$1" = "single" ] ; then
    export SCHEDULING_MODE=single
else
    echo "Bad scheduling mode '$1'" >&2
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
MUC_R_HOME="$(cd -P "$(dirname "$path")/.." >/dev/null 2>&1 && pwd)"

# MUC_R_HOME: directory of `load_all.R` script etc.
export MUC_R_HOME

cd -P "$(echo "$SLURMD_NODENAME" | md5sum | cut -c -2)/${SLURMD_NODENAME}/work" || \
    exit 101
NODEDIR="$(pwd)"
# NODEDIR: node-local directory, for file system reasons
export NODEDIR

# workdir: 
WORKDIR="${NODEDIR}/$(printf "%02d\n" "$((RANDOM%100))")/$(printf "%02d\n" "$((RANDOM%100))")"

mkdir -p "$WORKDIR"
