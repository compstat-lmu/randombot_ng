#!/bin/bash
#SBATCH --mail-type=end
#SBATCH --mem=MaxMemPerNode
#SBATCH --nodes=316
#SBATCH --cpus-per-task=1
#SBATCH --mail-user=martin.binder@stat.uni-muenchen.de
#SBATCH --export=NONE
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

# Expects the variable SBATCH_INDEX to be between 0 and 19
# This is set while running sbatch:
# $ sbatch <filename> --export=SBATCH_INDEX=$i

# Expects the variable SCHEDULING_MODE to be one of 'perseed', 'perparam',
# 'percpu'

echo "Salve, Job ${SLURM_JOB_NAME}:${SLURM_JOB_ID} index ${SBATCH_INDEX} scheduling mode ${SCHEDULING_MODE}. Laboraturi Te Salutant."

if ! [ -d "$MUC_R_HOME" ] ; then
    echo "MUC_R_HOME Not a directory: $MUC_R_HOME"
    exit 101
fi

. "$MUC_R_HOME/scheduling/common.sh"



check_env BASEDIR SCHEDULING_MODE USE_PARALLEL INDEXSTEPSIZE CONTROL_JOB_COUNT \
	  SBATCH_INDEX



TOEXEC="${MUC_R_HOME}/scheduling/invoke_srun.sh"
if [ "$CONTROL_JOB_COUNT" = 0 ] ; then
    export TOTAL_TASK_SLOTS=SLURM_NTASKS
    "$TOEXEC"
else
    # adding 'CONTROL_JOB_COUNT - 1' for rounding up!
    export TOTAL_TASK_SLOTS=SLURM_NTASKS
    export INDIVIDUAL_TASK_SLOTS=$(( (SLURM_NTASKS + CONTROL_JOB_COUNT - 1) / CONTROL_JOB_COUNT))
    ORIG_SBATCH_INDEX="$SBATCH_INDEX"
    INDEXSTEPSIZE="$((INDEXSTEPSIZE * CONTROL_JOB_COUNT))"
    for ((IDX=0;IDX<"$CONTROL_JOB_COUNT";IDX++)) ; do
	SBATCH_INDEX="$((ORIG_SBATCH_INDEX * CONTROL_JOB_COUNT + IDX))"
	srun --nodes=1 --ntasks=1 --exclusive --export=ALL \
	     $CONTROL_JOB_ARGS "$TOEXEC" | \
	    grep --line-buffered '^' &
    done
    wait
fi
