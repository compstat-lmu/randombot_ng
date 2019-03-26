#!/bin/bash
# This script calls the `srun` commands in the way the SCHEDULING_MODE requires.
# Should be invoked directly or indirectly by `sbatch.cmd`.

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

check_env BASEDIR SCHEDULING_MODE USE_PARALLEL INDEXSTEPSIZE SBATCH_INDEX \
	  TOTAL_TASK_SLOTS INDIVIDUAL_TASK_SLOTS

# maximum seed, should be larger than the largest realistic seed.
MAXINDEX=10000000000

# job log file where `parallel` progress is saved.
JOBLOGFILE="${BASEDIR}/parallel_joblogs/JOBLOG_${SCHEDULING_MODE}_${SBATCH_INDEX}_of_${INDEXSTEPSIZE}.log"

# number of `srun`s to have in the pipe at the same time.
CONCURRENCY=$(( (INDIVIDUAL_TASK_SLOTS - CONTROL_JOB_COUNT) )) # * SLURM_CPUS_ON_NODE)) TODO
export PERCPU_STEPSIZE=TODO # TODO
get_mem_req() {
    # arguments: learner, task
    # TODO
    echo 80G  # TODO
}

DATADIR=$(Rscript -e " \
  scriptdir <- Sys.getenv('MUC_R_HOME'); \
  inputdir <- file.path(scriptdir, 'input'); \
  suppressPackageStartupMessages( \
    source(file.path(scriptdir, 'load_all.R'), chdir = TRUE)); \
  source(file.path(inputdir, 'constants.R'), chdir = TRUE); \
  cat(rbn.getSetting('DATADIR'))
")

check_env DATADIR

SCRIPTDIR="${MUC_R_HOME}/scheduling"


call_srun() {  # arguments: <learner> <task> <seed / cmd>
    learner="$1"
    task="$2"
    argument="$3"
    # TODO: infer memory requirement from $1 and $2
    memreq="$(get_mem_req "$learner" "$task")"  # TODO

    srun --unbuffered --export=ALL \
	--mem="${memreq}" --nodes=1 --ntasks=1 --exclusive \
	"${SCRIPTDIR}/runscript.sh" \
	"$SCHEDULING_MODE" "$task" "$learner" "$argument" 2>&1 | \
	sed -u "s'^'[${task},${learner},${argument}]: '" | \
	grep --line-buffered '^'
    # About the `grep --line-buffered`: not sure if `sed -u` suffices, but:
    # We want each write to stdout be atomic, so different output lines
    # are not interleaved.
}

export -f call_srun


if [ "$SCHEDULING_MODE" = perseed ] ; then
    
    if [ "$USE_PARALLEL" = "TRUE" ] ; then
	seq "$SBATCH_INDEX" "$INDEXSTEPSIZE" "$MAXINDEX" | \
	    "$SCRIPTDIR/parallel" \
		--line-buffer \
		--joblog "${JOBLOGFILE}" \
		--jobs "${CONCURRENCY}" \
		--resume \
		call_srun {3} {2} {1} \
		:::: - \
		:::: "${DATADIR}/TASKS" \
		:::: "${DATADIR}/LEARNERS"
    else
	for ((i="$SBATCH_INDEX";i<="$MAXINDEX";i+="$INDEXSTEPSIZE")) ; do
	    while read -u 5 task ; do
		while read -u 6 learner ; do
		    call_srun "${learner}" "${task}" "${i}" &
		done 6<"${DATADIR}/TASKS"
	    done 5<"${DATADIR}/LEARNERS"
	    while [ $(jobs -r | wc -l) -gt "$((CONCURRENCY * 2))" ] ; do
		sleep 0.1
	    done
	done
	wait
    fi
elif [ "$SCHEDULING_MODE" = perparam ] ; then
    if [ "$USE_PARALLEL" = "TRUE" ] ; then
	zcat "${DATADIR}/INPUTS" | \
	    "$SCRIPTDIR/parallel" \
		--line-buffer \
		--joblog "$JOBLOGFILE" \
		--jobs "$CONCURRENCY" \
		--resume \
		--colsep ' ' \
		call_srun
    else
	declare -i i
	i="-$SBATCH_INDEX"
	while read learner task argument ; do
	    if [ "$((i % INDEXSTEPSIZE))" = 0 ] ; then
		call_srun "$learner" "$task" "$argument" &
	    fi
	    i+=1
	    if [ "$((i % CONCURRENCY))" = 0 ] ; then
		while [ $(jobs -r | wc -l) -gt "$((CONCURRENCY * 2))" ] ; do
		    sleep 0.1
		done
	    fi
	done < <(zcat "${DATADIR}/INPUTS")
	wait
    fi
elif [ "$SCHEDULING_MODE" = percpu ] ; then
    export PROGRESS
    while read -u 5 TASKNAME ; do
	while read -u 6 LEARNERNAME ; do
	    for ((i="$BATCH_INDEX";i<="$PERCPU_STEPSIZE";i+="$INDEXSTEPSIZE")) ; do
	        (
		    while true ; do
			get_progress_from_pointer "$i"
			call_srun "${i}" "${TASKNAME}" "${LEARNERNAME}"
		    done
		) &
	    done
	done 6<"${DATADIR}/TASKS"
    done 5<"${DATADIR}/LEARNERS"
    wait
else
    # should never happen
    echo "Scheduling mode $SCHEDULING_MODE dispatch error"
    exit 127
fi
