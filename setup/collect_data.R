#!/usr/bin/env Rscript

scriptdir <- Sys.getenv("MUC_R_HOME")
if (scriptdir == "") {
  stop("Environment variable MUC_R_HOME must be set.")
}
inputdir <- file.path(scriptdir, "input")

# load scripts & functions
source(file.path(scriptdir, "load_all.R"), chdir = TRUE)

# load custom learners & learner modifier
source(file.path(inputdir, "custom_learners.R"), chdir = TRUE)

# load constants
source(file.path(inputdir, "constants.R"), chdir = TRUE)

rbn.setupDataDir()

