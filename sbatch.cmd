#!/bin/bash
#SBATCH --mail-type=end
#SBATCH --mem=MaxMemPerNode
#SBATCH --nodes=316
#SBATCH --cpus-per-task=1
#SBATCH --mail-user=martin.binder@stat.uni-muenchen.de
#SBATCH --export=NONE
#SBATCH --time=48:00:00

# consciously omitting the following:
# -o output file: default "slurm-%j.out", where the "%j" is replaced with the job allocation number.
# -D directory, default CWD
# -J jobname, default script name
# don't need --ntasks, it is calculated from --nodes and --cpus-per-task

# Expects the variable SBATCH_INDEX to be between 0 and 19
# This is set while running sbatch:
# $ sbatch <filename> --export=SBATCH_INDEX=$i

# Expects the variable SCHEDULING_MODE to be one of 'perseed', 'perparam', 'percpu'

echo "Salve, Job ${SLURM_JOB_NAME}:${SLURM_JOB_ID} index ${SBATCH_INDEX} scheduling mode ${SCHEDULING_MODE}. Laboraturi Te Salutant."


if [ -z "${INDEXSTEPSIZE}" ] || ! [ "$INDEXSTEPSIZE" -gt 0 ] 2>/dev/null ; then
    echo "No valid INDEXSTEPSIZE: $INDEXSTEPSIZE"
    exit 1
fi

if [ -z "${SBATCH_INDEX}" ] || ! [ "$SBATCH_INDEX" -lt "$INDEXSTEPSIZE" -a "$SBATCH_INDEX" -ge 0 ] 2>/dev/null ; then
    echo "No valid SBATCH_INDEX: $SBATCH_INDEX"
    exit 2
fi

if ! [ -d "$MUC_R_HOME" ] ; then
    echo "MUC_R_HOME Not a directory: $MUC_R_HOME"
    exit 4
fi

if ! [ "$CONTROL_JOB_COUNT" -ge 0 ] ; then
    echo "Invalid CONTROL_JOB_COUNT: $CONTROL_JOB_COUNT"
    exit 5
fi

TOEXEC="${MUC_R_HOME}/scripts/runsrun.sh"
if [ "$CONTROL_JOB_COUNT" = 0 ] ; then
    "$TOEXEC"
else
    ORIG_SBATCH_INDEX="$SBATCH_INDEX"
    INDEXSTEPSIZE="$((INDEXSTEPSIZE * CONTROL_JOB_COUNT))"
    for ((IDX=0;IDX<"$CONTROL_JOB_COUNT";IDX++)) ; do
	SBATCH_INDEX="$((ORIG_SBATCH_INDEX * CONTROL_JOB_COUNT + IDX))"
	srun --nodes=1 --ntasks=1 --exclusive $CONTROL_JOB_ARGS "$TOEXEC"
    done
fi
