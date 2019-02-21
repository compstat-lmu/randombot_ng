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
JOBLOGFILE=TODO # TODO 
CONCURRENCY=TODO  # TODO
export PERCPU_STEPSIZE=TODO # TODO
get_mem_req() {
    # arguments: learner, task
    # TODO
    echo 1G
}

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
    memreq="$(get_mem_req "$learner" "$task")"  # TODO

    srun \
	--mem="${memreq}" --nodes=1 --ntasks=1 --exclusive \
	"${SCRIPTDIR}/runscript.sh" \
	"$SCHEDULING_MODE" "$task" "$learner" "$argument" | \
	sed -u "s'^'[${task},${learner},${argument}]: '"
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
		    call_srun "${i}" "${task}" "${learner}"
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
	wait
    fi
elif [ "$SCHEDULING_MODE" = percpu ] ; then
    while read -u 5 TASKNAME ; do
	while read -u 6 LEARNERNAME ; do
	    for ((i="$BATCH_INDEX";i<="$PERCPU_STEPSIZE";i+="$INDEXSTEPSIZE")) ; do
	        (
		    while true ; do
			PROGRESSSOURCE="${BASEDIR}/joblookup/${LEARNERNAME}/${TASKNAME}"
			PROGRESSPOINTER="${PROGRESSSOURCE}/PROGRESSPOINTER_${i}"
			NEWPF="${PROGRESSSOURCE}/PROGRESSFILE_${i}"


			if [ -f "$NEWPF" ] ; then
			    PROGRESS="$(cat "$NEWPF")"
			fi
			if ! [ "$PROGRESS" -ge 0 ] 2>/dev/null ; then
			    PROGRESS="$i"
			fi
			if [ -f "$PROGRESSPOINTER" ] ; then
			    OLDPF="$(cat "$PROGRESSPOINTER")"
			    if mv -f "$OLDPF" "${NEWPF}.tmp" ; then
				for ((i=0;i<180;i++)) ; do
				    if [ -f "${NEWPF}.tmp" ] ; then break ; fi
				    sleep 1
				done
			    fi
			    NEWPROGRESS="$(cat "${NEWPF}.tmp")"

			    if ! [ "$NEWPROGRESS" -ge "$PROGRESS" ] 2>/dev/null ; then
				rm -f "${NEWPF}.tmp"
			    else
				mv -f "${NEWPF}.tmp" "$NEWPF"
				PROGRESS="$NEWPROGRESS"
			    fi
			fi
			sleep 60  # wait for file changes to propagate; let's hope this is enough...
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
