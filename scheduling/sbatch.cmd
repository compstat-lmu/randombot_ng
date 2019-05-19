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

get_task_prob() {  # arguments: <task >
  task="$1"
  Rscript -e "setwd(file.path(Sys.getenv('MUC_R_HOME'))) ; source(file.path('R', 'get_data.R')); rbn.getTaskProbabilities('${task}')"
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
check_env DATADIR ONEOFF STRESSTEST STARTSEED SHARDS REDISPORT

# get the nodes on which redis-shards will be running as an array
readarray REDISNODES < <(scontrol show hostnames "$SLURM_JOB_NODELIST" | head -n "$SHARDS")

# some constants for redis & drain process quantity and memory usage
DRAIN_PER_SHARD=10
MEM_PER_DRAINER=2048
if [ "$((SLURM_MEM_PER_NODE - DRAIN_PER_SHARD * MEM_PER_DRAINER))" -lt "$((1024 * 40))" ] ; then
    echo "Not enough memory for redis & drainers: change constants in sbatch.cmd." >&2
    exit 21
fi

export REDISPW="$(head -c 128 /dev/urandom | sha1sum -b - | cut -c -40)"

mkdir RESULTS

PREVSHARDS="$(find REDIS -maxdepth 1 -type d -name 'REDISINSTANCE_*' 2>/dev/null | wc -l)"
if ! [ "${PREVSHARDS}" -eq 0 -o "${PREVSHARDS}" -eq "${SHARDS}" ] ; then
    echo "Found previous number of shards $PREVSHARDS unequal to requested number of shards $SHARDS. Exiting." >&2
    exit 31
fi

for ((CURSHARD=0;CURSHARD<SHARDS;CURSHARD++)) ; do
    (
	export CURSHARD
	CURNODE="${REDISNODES[$CURSHARD]}"
	if [ -f "REDISINFO_${CURSHARD}" ] ; then rm "REDISINFO_${CURSHARD}" || exit 102 ; fi
	echo "[MAIN,${CURSHARD}]: Starting Redis on $CURNODE"
	srun --unbuffered --export=ALL \
	     --mem="$((SLURM_MEM_PER_NODE - DRAIN_PER_SHARD * MEM_PER_DRAINER))" \
	     --nodes=1 --ntasks=1 --nodelist="$CURNODE" \
	     "${SCRIPTDIR}/runredis.sh" 2>&1 | \
	    sed -u "s'^'[REDIS,${CURSHARD}]: '" | \
	    grep --line-buffered '^' &
	while ! [ -f "REDISINFO_${CURSHARD}" ] ; do sleep 1 ; done
	export REDISHOST="$(cat "REDISINFO_${CURSHARD}" | cut -d : -f 1)"
	export REDISPORT="$(cat "REDISINFO_${CURSHARD}" | cut -d : -f 2)"
	export REDISPW="$(cat "REDISINFO_${CURSHARD}" | cut -d : -f 3-)"
	echo "[MAIN,${CURSHARD}]: Redis running on host $REDISHOST port $REDISPORT password $REDISPW"
	check_env REDISHOST REDISPORT REDISPW
	
	echo "[MAIN,${CURSHARD}]: Trying to connect to redis..."
	setup_redis  # common.sh
	echo "[MAIN,${CURSHARD}]: Redis is up."
	
	echo "[MAIN,${CURSHARD}]: Launching ${DRAIN_PER_SHARD} drain processes on $CURNODE"
	srun --unbuffered --export=ALL --mem-per-cpu="${MEM_PER_DRAINER}" \
	     --ntasks="$DRAIN_PER_SHARD" --cpus-per-task=1 \
	     --nodelist="$CURNODE" --nodes=1 \
	     "${SCRIPTDIR}/drainredis.R" 2>&1 | \
	    sed -u "s'^'[DRAINREDIS,${CURSHARD}]: '" | \
	    grep --line-buffered '^' &
	
	echo "[MAIN,${CURSHARD}]: Drain processes up."
    ) &
done

wait

# check that REDISPORT and REDISPW are as expected
for ((CURSHARD=0;CURSHARD<SHARDS;CURSHARD++)) ; do
    if [ "$(cat "REDISINFO_${CURSHARD}" | cut -d : -f 2)" != "$REDISPORT" ] ; then
	echo "REDISPORT for shard ${CURSHARD} differs from $REDISPORT" >&2
	exit 30
    fi
    if [ "$(cat "REDISINFO_${CURSHARD}" | cut -d : -f 3-)" != "$REDISPW" ] ; then
	echo "REDISPW for shard ${CURSHARD} differs from $REDISPW" >&2
	exit 31
    fi
done

# export list of REDISHOST
export REDISHOSTLIST="$(
    for ((CURSHARD=0;CURSHARD<SHARDS;CURSHARD++)) ; do 
	cat "REDISINFO_${CURSHARD}" | cut -d : -f 1
    done
)"

check_env REDISHOSTLIST

echo "[MAIN]: Calculating job step node assignment. This may take a minute or two."
if [ -e STEPNODES ] ; then rm -r STEPNODES || exit 103 ; fi
scontrol show hostnames "$SLURM_JOB_NODELIST" | tail -n "+$((SHARDS + 1))" | \
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
    ( while true ; do 
	  srun --unbuffered --export=ALL --exclusive \
	       --mem-per-cpu="${memcosts}M" --ntasks="$ntasks" \
	       --nodelist="STEPNODES/${data}_${learner}.nodes" \
	       --nodes="1-${SLURM_JOB_NUM_NODES}" \
	       --immediate \
    	       /bin/sh -c "${SCRIPTDIR}/runscript.sh \"${data}\" \"${learner}\" \"${STARTSEED}\" \"${ONEOFF}\" \"${STRESSTEST}\" 2>&1 | sed -u \"s'^'[\${SLURM_PROCID}]: '\"" 2>&1 | \
	      sed -u "s'^'[${data},${learner}]'"
	  echo "[${data},${learner}]: SRUN returned with status $?"
	  sleep 60
	  echo "[${data},${learner}]: retrying"
      done ) &
done <STEPNODES/STEPS

wait
