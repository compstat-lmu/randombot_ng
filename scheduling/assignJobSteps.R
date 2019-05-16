#!/usr/bin/env Rscript

scriptdir <- Sys.getenv("MUC_R_HOME")
inputdir <- file.path(scriptdir, "input")

# load scripts & functions
source(file.path(scriptdir, "load_all.R"), chdir = TRUE)

# load custom learners & learner modifier
source(file.path(inputdir, "custom_learners.R"), chdir = TRUE)

# load constants
source(file.path(inputdir, "constants.R"), chdir = TRUE)

sti <- file("stdin")
nodes <- grep("^ *$", readLines(sti), value = TRUE, invert = TRUE)
close(sti)

assgn <- rbn.DistributeSrunsToNodes.GREEDY(nodes)

assgnmat <- aggregate(assgn$node, by = assgn[c("data", "learner")],
  FUN = paste, collapse = ",")

asx <- aggregate(assgn$node, by = assgn[c("data", "learner", "memcosts")],
  FUN = length)

dir.create("STEPNODES", showWarnings = FALSE)

apply(assgnmat, 1, function(row) {
  writeLines(row[3],
    file.path("STEPNODES", sprintf("%s_%s.nodes", row[1], row[2])))
})

writeLines(paste(asx[["data"]], asx[["learner"]], asx[["memcosts"]], asx$x),
  file.path("STEPNODES", "STEPS"))

