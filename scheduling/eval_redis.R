# evaluate all points for a given TASKNAME and LEARNERNAME,
# skipping in increments of PERCPU_STEPSIZE
# reading progress from and writing it back to PROGRESSFILE

token <- Sys.getenv("TOKEN")

suppressPackageStartupMessages({
  library("BBmisc")
})
catf("----[%s] eval_redis.R", token)

library("redux")

r.host <- Sys.getenv("REDISHOST")
r.port <- Sys.getenv("REDISPORT")
r.port <- as.integer(r.port)

rcon <- NULL
catf("Connecting to redis %s:%s", r.host, r.port)
rcon <- hiredis(host = r.host, port = r.port)

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

queuename <- sprintf("QUEUE_%s_%s", LEARNERNAME, TASKNAME)

data <- rbn.getData(TASKNAME)
lrn <- rbn.getLearner(LEARNERNAME)
paramtable <- rbn.compileParamTblConfigured()

repeat {
  seet <- rcon$INCR(queuename)
  if (!is.numeric(nextseed)) {
    break
  }
  catf("----[%s] Evaluating seed %s", token, seed)
  points <- rbn.sampleEvalPoint(lrn, data$task, seed, paramtable)

  for (pt in points) {
    catf("----[%s] Evaluating point %s", token, pt)
    result <- rbn.evaluatePoint(lrn, pt, data)
    rbn.setWatchdogTimeout(600)  # ten minutes timeout to write result file

    r$SET(sprintf("RESULT_%s_%s_SD:%012.0f_%s", LEARNERNAME, TASKNAME, seed, pt),
      serialize(result, connection = NULL))
  }
  catf("----[%s] Done evaluating seed %s", token, seed)
}


catf("----[%s] seed was bad. Current seed: %s. Integer overflow? Ending.", token, seed)
