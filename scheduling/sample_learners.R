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

## We want to give the learners according to the proportion specified.
# If the proportions times the number of learners lead to an expected
# number of learners greater than one, we return those learners until
# the remaining expected learners are only fractional.
for (iter in seq_len(sum(proptable$whole))) {
  togive <- which.max(proptable$x * iter - proptable$given)
  cat(paste0(proptable$learner[togive], "\n"))
  proptable$given[togive] <- proptable$given[togive] + 1
}

stopifnot(all(proptable$given == proptable$whole))

proptable$x <- proptable$x * numlearners - proptable$given

stopifnot(all(proptable$x <= 1 & proptable$x >= 0))

remaining <- numlearners - sum(proptable$whole)

while (remaining) {
  if (remaining >= nrow(proptable)) {
    cat(paste0(proptable$learner[order(proptable$x, decreasing = TRUE)], "\n"), sep = "")
    break
  }
  consider <- which.max(proptable$x)
  if (runif(1) <= proptable$x[consider]) {
    cat(paste0(proptable$learner[consider], "\n"))
    proptable$x <- proptable$x * (sum(proptable$x) - 1) / sum(proptable$x[-consider])
    remaining <- remaining - 1
  } else {
    proptable$x <- proptable$x * sum(proptable$x) / sum(proptable$x[-consider])
  }
  proptable <- proptable[-consider, ]
  proptable$x <- pmax(proptable$x, 0)
}
