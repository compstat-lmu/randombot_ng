#!/bin/bash

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

lines="$1"

if [ -z "$2" ] ; then
    cores=1
else
    cores="$2"
fi
if ! [ "$lines" -ge 0 -a "$cores" -ge 0 ] 2>/dev/null ; then
    echo "Usage: $0 <number of lines to generate> [<cores>]" >&2
    exit 1
fi


Rscript -e " \
  options(error=recover); \
  scriptdir <- '$MUC_R_HOME'; \
  inputdir <- file.path(scriptdir, 'input'); \
  suppressPackageStartupMessages( \
    source(file.path(scriptdir, 'load_all.R'), chdir = TRUE)); \
  source(file.path(inputdir, 'custom_learners.R'), chdir = TRUE); \
  source(file.path(inputdir, 'constants.R'), chdir = TRUE); \
  paramtable <- rbn.compileParamTblConfigured(); \
  learners <- lapply(unique(paramtable[['learner']]), rbn.getLearner); \
  datatable <- rbn.loadDataTableConfigured(); \
  datas <- lapply(datatable[['name']], function(x) rbn.getData(x)[['task']]); \
  offset <- 0; \
  stepsize <- max(${cores}, \
    ceiling(${cores} * 10000  / length(learners) / length(datas)) \
  ); \
  linesnum <- ${lines}; \
  while (linesnum > 0) { \
    lines <- parallel::mclapply(seq_len(stepsize), mc.cores = ${cores}, \
    function(i) { \
      seed <- i + offset; \
      lapply(datas, function(data) { \
        lapply(learners, function(learner) { \
          sprintf('%s %s %s', learner[['id']], data[['task.desc']][['id']], rbn.sampleEvalPoint(learner, data, seed, paramtable)) \
        }) \
      }) \
    }); \
    lines <- unlist(lines); \
    linesout <- lines[seq_len(min(length(lines), linesnum))]; \
    offset <- offset + stepsize; \
    cat(linesout, sep = '\\n'); \
    linesnum <- linesnum - length(lines); \
  } \
" | gzip -f
