#!/usr/bin/env Rscript


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

print(proptable)
