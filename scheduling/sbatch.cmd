#!/bin/bash
#SBATCH --mail-type=end
#SBATCH --mem=MaxMemPerNode
#SBATCH --cpus-per-task=1
#SBATCH --mail-user=martin.binder@stat.uni-muenchen.de
#SBATCH --time=48:00:00

# This is the sbatch-script, should probably be scheduled by
# **invoke_sbatch.sh**. This either calls *invoke_srun.sh* directly or as
# dependend job steps CONTROL_JOB_COUNT number of times.

# consciously omitting the following:
# -o output file: default "slurm-%j.out", where the "%j" is replaced with the
#    job allocation number.
# -D directory, default CWD
# -J jobname, default script name
# don't need --ntasks, it is calculated from --nodes and --cpus-per-task

# Expects the variable SCHEDULING_MODE to be one of 'perseed', 'perparam',
# 'percpu'

echo "Salve, Job ${SLURM_JOB_NAME}:${SLURM_JOB_ID}. Laboraturi Te Salutant."

if ! [ -d "$MUC_R_HOME" ] ; then
    echo "MUC_R_HOME Not a directory: $MUC_R_HOME"
    exit 101
fi

. "$MUC_R_HOME/scheduling/common.sh"

export TOTAL_TASK_SLOTS=""
export INDIVIDUAL_TASK_SLOTS="$SLURM_NTASKS"

get_mem_req() {  # arguments: <learner> <task >
  learner="$1"
  task="$2"
  Rscript -e 'source("R/get_data.R"); rbn.getMemoryRequirementsKb(task, learner)'
}

DATADIR=$(Rscript -e " \
  scriptdir <- Sys.getenv('MUC_R_HOME'); \
  inputdir <- file.path(scriptdir, 'input'); \
  suppressPackageStartupMessages( \
    source(file.path(scriptdir, 'load_all.R'), chdir = TRUE)); \
  source(file.path(inputdir, 'constants.R'), chdir = TRUE); \
  cat(rbn.getSetting('DATADIR'))
")

check_env DATADIR ONEOFF REDISHOST REDISPORT REDISPW

SCRIPTDIR="${MUC_R_HOME}/scheduling"

INVOCATION=0
call_srun() {  # arguments: <learner> <task> <message to prepend output>
    learner="$1"
    task="$2"
    si="$3"
    # TODO: infer memory requirement from $1 and $2
    memreq="$(get_mem_req "$learner" "$task")"  # TODO

    srun --unbuffered --export=ALL \
	--mem="${memreq}" --nodes=1 --ntasks=1 --exclusive \
	"${SCRIPTDIR}/runscript.sh" \
	"$task" "$learner" "$ONEOFF" 2>&1 | \
	sed -u "s'^'[${task},${learner},${INVOCATION},${si}]: '" | \
	grep --line-buffered '^'
    # About the `grep --line-buffered`: not sure if `sed -u` suffices, but:
    # We want each write to stdout be atomic, so different output lines
    # are not interleaved.
}

NUMTASKS="$(grep -v '^ *$' "${DATADIR}/TASKS" | wc -l)"

while read -u 6 LEARNERNAME ; do
    while read -u 5 TASKNAME ; do
	(
	    SUBINVOCATION=0
	    while true ; do
		call_srun "${LEARNERNAME}" "${TASKNAME}" "${SUBINVOCATION}"
		SUBINVOCATION=$((SUBINVOCATION + 1))
	    done
	) &
	INVOCATION=$((INVOCATION + 1))
    done 5<"${DATADIR}/TASKS"
    if ! [ "$SLURM_NTASKS" -ge $((INVOCATION + NUMTASKS)) ] ; then
	# as many workers running as there are tasks
	break
    fi
done 6<"${DATADIR}/LEARNERS"
wait
