#!/bin/bash
#SBATCH -o 
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

if ! [ -d "$MUC_R_HOME" ] ; then
    echo "MUC_R_HOME Not a directory: $MUC_R_HOME"
    exit 4
fi

"${MUC_R_HOME}/scripts/runsrun.sh"
