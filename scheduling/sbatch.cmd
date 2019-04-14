#!/bin/bash
#SBATCH --mem=MaxMemPerNode
#SBATCH --cpus-per-task=1
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
check_env DATADIR ONEOFF STRESSTEST STARTSEED DRAINPROCS REDISPORT

if [ -f REDISINFO ] ; then rm REDISINFO || exit 102 ; fi
echo "[MAIN]: Starting Redis"
srun --unbuffered --export=ALL --mem="$SLURM_MEM_PER_NODE" --nodes=1 --ntasks=1 \
     --nodelist="$SLURM_NODENAME" \
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


if echo "$DRAINPROCS" | grep 'N$' > /dev/null ; then
    DRAINPROCS="$(echo "$DRAINPROCS" | sed 's/N$//')"
    DRAINPROCS=$((DRAINPROCS * (SLURM_MEM_PER_NODE / 2048)))
fi

mkdir RESULTS
# number of nodes to allocate is DRAINPROCS / [slots per node]
# - [slots per node] is the available memory divided by 2GB
# - we want to round UP, but bash arithmetic rounds down, so we do
#   (DRAINPROCS + [slots per node] - 1)  / [slots per node]
DRAINNODES=$(((DRAINPROCS + (SLURM_MEM_PER_NODE / 2048) - 1) / (SLURM_MEM_PER_NODE / 2048)))
DNLIST="$(echo "$SLURM_NODENAME" | \
	     cat - <(scontrol show hostnames "$SLURM_JOB_NODELIST") | \
	     sort | uniq -u | head -n "$DRAINNODES" | tr $'\n' ',')"
echo "[MAIN]: Launching $DRAINPROCS drain processes on $DRAINNODES nodes"
srun --unbuffered --export=ALL --mem "$SLURM_MEM_PER_NODE" --ntasks="$DRAINPROCS" \
     --nodelist="$DNLIST" \
     --nodes="$DRAINNODES" "${SCRIPTDIR}/drainredis.R" 2>&1 | \
    sed -u "s'^'[DRAINREDIS]: '" | \
    grep --line-buffered '^' &

echo "[MAIN]: Drain processes up."

echo "[MAIN]: Calculating job step node assignment. This may take a minute or two."
if [ -e STEPNODES ] ; then rm -r STEPNODES || exit 103 ; fi
cat <(echo "$SLURM_NODENAME") \
    <(echo "$DNLIST" | tr ',' $'\n') \
    <(scontrol show hostnames "$SLURM_JOB_NODELIST") | sort | uniq -u | \
    "${SCRIPTDIR}/assignJobSteps.R"
echo "[MAIN]: Done calculating."

echo "[MAIN]: Looping over STEPNODES/STEPS to create worker job steps"

while read data learner memcosts ntasks ; do

# OOM job step kills rely on MemLimitEnforce=yes and JobAcctGatherParams=OverMemoryKill.
# If they are not set, then job-steps don't get OOM-killed, instead the cgroups limit
# process memory.
# We therefore need to make sure these parameters are not set. They are not on
# Supermuc NG, so this should be fine.
    echo "[MAIN]: Creating $ntasks tasks working on $data with ${learner}, memcost: ${memcosts}M"
    srun --unbuffered --export=ALL --exclusive \
	 --mem-per-cpu="${memcosts}M" --ntasks="$ntasks" \
	 --nodelist="STEPNODES/${data}_${learner}.nodes" \
	 /bin/sh -c "${SCRIPTDIR}/runscript.sh \"${data}\" \"${learner}\" \"${STARTSEED}\" \"${ONEOFF}\" \"${STRESSTEST}\" 2>&1 | sed -u \"s'^'[${task},${learner},\${SLURM_LOCALID}]: '\"" \
	grep --line-buffered '^' &
done <STEPNODES/STEPS

wait
