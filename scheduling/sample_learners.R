#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (!length(args) ||
    !is.finite(numlearners <- as.numeric(args[1])) ||
    numlearners != abs(round(numlearners))) {
  stop("Usage: sample_learners.R <number of learners>")
}

scriptdir <- Sys.getenv("MUC_R_HOME")
inputdir <- file.path(scriptdir, "input")

# load scripts & functions
source(file.path(scriptdir, "load_all.R"), chdir = TRUE)

# load custom learners & learner modifier
source(file.path(inputdir, "custom_learners.R"), chdir = TRUE)

# load constants
source(file.path(inputdir, "constants.R"), chdir = TRUE)

table <- rbn.compileParamTblConfigured()

proptable <- aggregate(table$proportion, by = table["learner"], FUN = mean)

proptable$x <- proptable$x / sum(proptable$x)


proptable$whole <- floor(proptable$x * numlearners)

proptable$given <- 0

for (iter in seq_len(sum(proptable$whole))) {
  togive <- which.max(proptable$x * iter - proptable$given)
  cat(paste0(proptable$learner[togive], "\n"))
  proptable$given[togive] <- proptable$given[togive] + 1
}
