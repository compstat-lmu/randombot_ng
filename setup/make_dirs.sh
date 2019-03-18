#!/bin/bash

if [ -z "$2" ] 2>/dev/null ; then
    echo "Usage: $0 BASEDIR FILE" >&2
    echo "$0: create working directories on supermuc, of the shape BASEDIR/xx/nodename/work/ for =nodename= read from file FILE ('-' for stdin), and =xx= being the first two characters of =md5sum nodename=" >&2
    echo "The /work/ directory can be used node-locally, but if many files are going to be written, the .../work/kk/ folders should be used." >&2
    echo "Further directories are of the form BASEDIR/joblookup/LEARNER/TASK and are inferred from input/constants.R"
    exit 1
fi

BASEDIR="$1"

if [[ "$BASEDIR" == *"'"* ]] ; then
    echo "Illegal \"'\" character in BASEDIR." >&2
    exit 2
fi

if ! [ -d "$BASEDIR" ] ; then
    echo "BASEDIR $BASEDIR is not a directory." >&2
    exit 3
fi

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

DATADIR=$(Rscript -e " \
  scriptdir <- '$MUC_R_HOME'; \
  inputdir <- file.path(scriptdir, 'input'); \
  suppressPackageStartupMessages( \
    source(file.path(scriptdir, 'load_all.R'), chdir = TRUE)); \
  source(file.path(inputdir, 'constants.R'), chdir = TRUE); \
  cat(rbn.getSetting('DATADIR'))
")

"${MUC_R_HOME}/scheduling/parallel" \
    echo -ne "${BASEDIR}/joblookup/{1}/{2}\\\\0" \
    :::: "${DATADIR}/LEARNERS" \
    :::: "${DATADIR}/TASKS" | \
    xargs -0 mkdir -p

mkdir "${BASEDIR}/parallel_joblogs"


cat "$2" | while read NODENAME ; do
    echo -ne "${BASEDIR}/$(echo "$NODENAME" | md5sum | cut -c -2)/${NODENAME}/work\0"
done | xargs -0 mkdir -p
