# evaluate all points for a given TASKNAME and LEARNERNAME,
# skipping in increments of PERCPU_STEPSIZE
# reading progress from and writing it back to PROGRESSFILE

token <- Sys.getenv("TOKEN")

catf("----[%s] eval_multiple.R", token)

scriptdir <- Sys.getenv("MUC_R_HOME")
inputdir <- file.path(scriptdir, "input")

# load scripts & functions
source(file.path(scriptdir, "load_all.R"), chdir = TRUE)

# load custom learners & learner modifier
source(file.path(inputdir, "custom_learners.R"), chdir = TRUE)

# load constants
source(file.path(inputdir, "constants.R"), chdir = TRUE)

LEARNERNAME <- Sys.getenv("LEARNERNAME")
TASKNAME <- Sys.getenv("TASKNAME")
PROGRESSFILE <- Sys.getenv("PROGRESSFILE")
PROGRESSTMP <- paste0(PROGRESSFILE, ".tmp")
PERCPU_STEPSIZE <- Sys.getenv("PERCPU_STEPSIZE")

data <- rbn.getData(TASKNAME)
lrn <- rbn.getLearner(LEARNERNAME)
paramtable <- rbn.compileParamTblConfigured()

seed <- as.integer(readLines(PROGRESSFILE)[1])
catf("----[%s] Read seed %s from PROGRESSFILE %s", token, seed, PROGRESSFILE)
repeat {
  nextseed <- seed + PERCPU_STEPSIZE
  if (is.na(nextseed)) {
    break
  }
  writeLines(as.character(nextseed), PROGRESSTMP)
  file.rename(PROGRESSTMP, PROGRESSFILE)

  catf("----[%s] Evaluating seed %s", token, seed)
  points <- rbn.sampleEvalPoint(lrn, data$task, ARGUMENT, paramtable)

  for (pt in points) {
    catf("----[%s] Evaluating point %s", token, pt)
    result <- rbn.evaluatePoint(lrn, pt, data)
    rbn.setWatchdogTimeout(600)  # ten minutes timeout to write result file
    rbn.writeResult(result, ARG)
  }

  catf("----[%s] Done evaluating seed %s", token, seed)
  seed <- nextseed
}


catf("----[%s] nextseed was NA. Current seed: %s. Integer overflow? Ending.", token, seed)
