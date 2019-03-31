#!/bin/bash
#SBATCH --mail-type=end
#SBATCH --mem=MaxMemPerNode
#SBATCH --cpus-per-task=1
#SBATCH --mail-user=martin.binder@stat.uni-muenchen.de
#SBATCH --time=48:00:00

# consciously omitting the following:
# -o output file: default "slurm-%j.out", where the "%j" is replaced with the
#    job allocation number.
# -D directory, default CWD
# -J jobname, default script name
# don't need --ntasks, it is calculated from --nodes and --cpus-per-task

# Expects the variable SCHEDULING_MODE to be one of 'perseed', 'perparam',
# 'percpu'

echo "[MAIN]: Salve, Job ${SLURM_JOB_NAME}:${SLURM_JOB_ID}. Laboraturi Te Salutant."

if ! [ -d "$MUC_R_HOME" ] ; then
    echo "MUC_R_HOME Not a directory: $MUC_R_HOME"
    exit 101
fi

. "$MUC_R_HOME/scheduling/common.sh"
SCRIPTDIR="${MUC_R_HOME}/scheduling"

get_mem_req() {  # arguments: <learner> <task >
  learner="$1"
  task="$2"
  Rscript -e "setwd(file.path(Sys.getenv('MUC_R_HOME'))) ; source(file.path('R', 'get_data.R')); rbn.getMemoryRequirementsKb('${task}', '${learner}')"
}

echo "[MAIN]: Getting DATADIR"
DATADIR=$(Rscript -e " \
  scriptdir <- Sys.getenv('MUC_R_HOME'); \
  inputdir <- file.path(scriptdir, 'input'); \
  suppressPackageStartupMessages( \
    source(file.path(scriptdir, 'load_all.R'), chdir = TRUE)); \
  source(file.path(inputdir, 'constants.R'), chdir = TRUE); \
  cat(rbn.getSetting('DATADIR'))
")
echo "[MAIN]: Using DATADIR $DATADIR"
check_env DATADIR ONEOFF STRESSTEST STARTSEED DRAINPROCS

if [ -f REDISINFO ] ; then rm REDISINFO || exit 102 ; fi
echo "[MAIN]: Starting Redis"
srun --unbuffered --export=ALL --mem="$SLURM_MEM_PER_NODE" --nodes=1 --ntasks=1 \
     "${SCRIPTDIR}/runredis.sh" 2>&1 | \
    sed -u "s'^'[REDIS]: '" | \
    grep --line-buffered '^' &
while ! [ -f REDISINFO ] ; do sleep 1 ; done
export REDISHOST="$(cat REDISINFO | cut -d : -f 1)"
export REDISPORT="$(cat REDISINFO | cut -d : -f 2)"
export REDISPW="$(cat REDISINFO | cut -d : -f 3-)"
echo "[MAIN]: Redis running on host $REDISHOST port $REDISPORT password $REDISPW"
check_env REDISHOST REDISPORT REDISPW

echo "[MAIN]: Trying to connect to redis..."
while [ "$connok" != "OK" ] ; do
    sleep 1
    connok="$(Rscript -e 'cat(sprintf("auth %s\n", Sys.getenv("REDISPW")))' | \
        redis-cli -h "$REDISHOST" -p "$REDISPORT" 2>/dev/null)"
done
echo "[MAIN]: Redis is up."


echo "[MAIN]: Launching drain processes."
mkdir RESULTS
# number of nodes to allocate is DRAINPROCS / [slots per node]
# - [slots per node] is the available memory divided by 2GB
# - we want to round UP, but bash arithmetic rounds down, so we do
#   (DRAINPROCS + [slots per node] - 1)  / [slots per node]
DRAINNODES=$(((DRAINPROCS + (SLURM_MEM_PER_NODE / 2048) - 1) / (SLURM_MEM_PER_NODE / 2048)))
echo "[MAIN]: Launching $DRAINPROCS drain processes on $DRAINNODES nodes"
srun --unbuffered --export=ALL --mem "$SLURM_MEM_PER_NODE" --ntasks="$DRAINPROCS" \
     --nodes="$DRAINNODES" "${SCRIPTDIR}/drainredis.R" 2>&1 | \
    sed -u "s'^'[DRAINREDIS]: '" | \
    grep --line-buffered '^' &

echo "[MAIN]: Drain processes up."


INVOCATION=0
call_srun() {  # arguments: <learner> <task> <message to prepend output>
    learner="$1"
    task="$2"
    si="$3"
    # TODO: infer memory requirement from $1 and $2
    memreq="$4"

    srun --unbuffered --export=ALL --exclusive \
	--mem="${memreq}" --nodes=1 --ntasks=1 \
	"${SCRIPTDIR}/runscript.sh" \
	"$task" "$learner" "$STARTSEED" "$ONEOFF" "$STRESSTEST" 2>&1 | \
	sed -u "s'^'[${task},${learner},${INVOCATION},${si}]: '" | \
	grep --line-buffered '^'
    # About the `grep --line-buffered`: not sure if `sed -u` suffices, but:
    # We want each write to stdout be atomic, so different output lines
    # are not interleaved.
}

NUMTASKS="$(grep -v '^ *$' "${DATADIR}/TASKS" | wc -l)"

NUM_CPUS="$(echo "$SLURM_JOB_CPUS_PER_NODE" | tr ',(x)' $'\n'' ' | awk '{ x += $1 * ($2?$2:1) } END { print x }')"

while read -u 6 LEARNERNAME ; do
    while read -u 5 TASKNAME ; do
	if [ "$STRESSTEST" = "TRUE" ] ; then
	    MEMREQ=1G
	else
	    MEMREQ="$(get_mem_req "$learner" "$task")"
	fi
	(
	    SUBINVOCATION=0
	    while true ; do
		call_srun "${LEARNERNAME}" "${TASKNAME}" "${SUBINVOCATION}" "${MEMREQ}"
		SUBINVOCATION=$((SUBINVOCATION + 1))
	    done
	) &
	INVOCATION=$((INVOCATION + 1))
    done 5<"${DATADIR}/TASKS"
done 6< <( "$SCRIPTDIR/sample_learners.R" "$NUM_CPUS" )
wait
