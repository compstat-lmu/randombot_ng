#!/bin/bash
# run script, to be launched using `srun` in an sbatch command file
# Expectations:
# - This file is not copied somewhere else, but instead ran from its path
#   in the randombot_ng/scheduling directory
# - command line is $0 <TASKNAME> <LEARNERNAME> <ONEOFF (optional)>
# - ONEOFF, if given, must be one of TRUE or FALSE (default)

export TASKNAME="$1"
export LEARNERNAME="$2"
export ONEOFF="$3"

if [ -z "$LEARNERNAME" ]; then
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


check_env ONEOFF REDISHOST REDISPORT REDISPW STRESSTEST STARTSEED


## benchmark stdout
# for ((i = 0 ; i < 10 ; i++)) ; do date +"%s.%N" ; done
# env | cut -c -4095
# for ((i = 0 ; i < 10 ; i++)) ; do date +"%s.%N" ; done

INNERSTEP=0

while true ; do
    export TOKEN="$(date +"%F_%T")_${HOSTNAME}"

    # absolutely need to pipe stderr into stdout, otherwise srun mixes the two streams
    /usr/bin/time -f "[[${INNERSTEP}]] ----[$TOKEN] E %E K %Ss U %Us P %P M %MkB O %O" \
		  Rscript "$MUC_R_HOME/scheduling/eval_redis.R" 2>&1
    result=$?
    
    echo "[[${INNERSTEP}]] ----[${TOKEN}] ${evalfile} exited with status $result"
    INNERSTEP=$((INNERSTEP + 1))
done

exit $result
