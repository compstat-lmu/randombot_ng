# evaluate a single point, either given as string of arguments "list()" or seed number
# info given through TASKNAME, LEARNERNAME and ARGUMENT
token <- Sys.getenv("TOKEN")

suppressPackageStartupMessages({
  library("BBmisc")
})
catf("----[%s] eval_single.R", token)

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
ARGUMENT <- Sys.getenv("ARGUMENT")

data <- rbn.getData(TASKNAME)
lrn <- rbn.getLearner(LEARNERNAME)

if (substr(ARGUMENT, 1, 4) != "list") {
  catf("----[%s] Argument %s used as seed", token, ARGUMENT)
  ARGUMENT <- as.integer(ARGUMENT)
  paramtable <- rbn.compileParamTblConfigured()
  ARGUMENT <- rbn.sampleEvalPoint(lrn, data$task, ARGUMENT, paramtable)
  catf("----[%s] Generated %s eval points", token, length(ARGUMENT))
}

for (ARG in ARGUMENT) {
  catf("----[%s] Evaluating %s", token, ARG)
  result <- rbn.evaluatePoint(lrn, ARG, data)
  rbn.writeResult(result, TASKNAME, LEARNERNAME, ARG)
}
catf("----[%s] END OF eval_single.R", token)
