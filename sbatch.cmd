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

if [ -z "${INDEXSTEPSIZE}" ] || ! [ "$INDEXSTEPSIZE" -gt 0 ] 2>/dev/null ; then
    echo "No valid INDEXSTEPSIZE: $INDEXSTEPSIZE"
    exit 1
fi

if [ -z "${SBATCH_INDEX}" ] || ! [ "$SBATCH_INDEX" -lt "$INDEXSTEPSIZE" -a "$SBATCH_INDEX" -ge 0 ] 2>/dev/null ; then
    echo "No valid SBATCH_INDEX: $SBATCH_INDEX"
    exit 2
fi

if ! [[ "${SCHEDULING_MODE}" =~ ^per(seed|param|cpu)$ ]] ; then
    echo "No valid SCHEDULING_MODE: $SCHEDULING_MODE"
    exit 3
fi

if ! [ -d "$MUC_R_HOME" ] ; then
    echo "MUC_R_HOME Not a directory: $MUC_R_HOME"
    exit 4
fi

if ! [ -d "$BASEDIR" ] ; then
    echo "BASEDIR Not a directory: $BASEDIR"
    exit 5
fi

if ! [[ "${USE_PARALLEL}" =~ ^(TRUE|FALSE)$ ]] ; then
    echo "No valid USE_PARALLEL: $USE_PARALLEL"
    exit 6
fi

MAXINDEX=10000000000  # maximum seed

DATADIR=$(Rscript -e " \
  scriptdir <- '$MUC_R_HOME'; \
  inputdir <- file.path(scriptdir, 'input'); \
  suppressPackageStartupMessages( \
    source(file.path(scriptdir, 'load_all.R'), chdir = TRUE)); \
  source(file.path(inputdir, 'constants.R'), chdir = TRUE); \
  cat(rbn.getSetting('DATADIR'))
")

SCRIPTDIR="${MUC_R_HOME}/scripts"

if ! [ -d "$DATADIR" ] ; then
    echo "Inferred DATADIR Not a directory: $DATADIR"
    exit 6
fi




call_srun() {  # arguments: <seed/line> <task> <learner>
    learner="$1"
    task="$2"
    argument="$3"
    # TODO: infer memory requirement from $1 and $2
    memreq=1G  # TODO

    srun \
	--mem="${memreq}" --nodes=1 --ntask=1 --exclusive \
	"${SCRIPTDIR}/runscript.sh" \
	"$SCHEDULING_MODE" "$task" "$learner" "$argument" | \
	sed -u "s'^'[${task},${learner},${argument}]: '"
}

export -f call_srun

JOBLOGFILE=TODO # TODO 
CONCURRENCY=TODO  # TODO

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
	for ((i="$SBATCH_INDEX";i<="$MAXINDEX";i++)) ; do
	    while read -u 5 task ; do
		while read -u 6 learner ; do
		    call_srun "${i}" "${task}" "${learner}"
		done 6<"${DATADIR}/TASKS"
	    done 5<"${DATADIR}/LEARNERS"
	    while [ $(jobs -r | wc -l) -gt "$((CONCURRENCY * 2))" ] ; do
		sleep 0.1
	    done
	done
    fi
elif [ "$SCHEDULING_MODE" = perparam ] ; then
    if [ "$USE_PARALLEL" = "TRUE" ] ; then
	"$SCRIPTDIR/parallel" \
	    --line-buffer \
	    --joblog "$JOBLOGFILE" \
	    --jobs "$CONCURRENCY" \
	    --resume \
	    --colsep ' ' \
	    call_srun \
	    :::: "${DATADIR}/INPUTS"
    else
	declare -i i
	i="-$SBATCH_INDEX"
	while read learner task argument ; do
	    if [ "$((i % INDEXSTEPSIZE))" = 0 ] ; then
		call_srun "$learner" "$task" "$argument"
	    fi
	    i+=1
	    if [ "$((i % CONCURRENCY))" = 0 ] ; then
		while [ $(jobs -r | wc -l) -gt "$((CONCURRENCY * 2))" ] ; do
		    sleep 0.1
		done
	    fi
	done <"${DATADIR}/INPUTS"
    fi
elif [ "$SCHEDULING_MODE" = percpu ] ; then
    TODO TODO TODO
else
    # should never happen
    echo "Scheduling mode $SCHEDULING_MODE dispatch error"
    exit 127
fi
