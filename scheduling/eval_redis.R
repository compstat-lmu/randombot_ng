# evaluate all points for a given TASKNAME and LEARNERNAME,
# skipping in increments of PERCPU_STEPSIZE
# reading progress from and writing it back to PROGRESSFILE

token <- Sys.getenv("TOKEN")

suppressPackageStartupMessages({
  library("BBmisc")
})
catf("----[%s] eval_redis.R", token)

scriptdir <- Sys.getenv("MUC_R_HOME")
inputdir <- file.path(scriptdir, "input")

# load scripts & functions
source(file.path(scriptdir, "load_all.R"), chdir = TRUE)

# load custom learners & learner modifier
source(file.path(inputdir, "custom_learners.R"), chdir = TRUE)

# load constants
source(file.path(inputdir, "constants.R"), chdir = TRUE)

rbn.setWatchdogTimeout(600)  # ten minutes timeout to connect to redux

library("redux")

r.host <- Sys.getenv("REDISHOST")
r.port <- Sys.getenv("REDISPORT")
r.pass <- Sys.getenv("REDISPW")
r.port <- as.integer(r.port)

oneoff <- Sys.getenv("ONEOFF")

rcon <- NULL
catf("----[%s] Connecting to redis %s:%s", token, r.host, r.port)
rcon <- hiredis(host = r.host, port = r.port, password = r.pass)


LEARNERNAME <- Sys.getenv("LEARNERNAME")
TASKNAME <- Sys.getenv("TASKNAME")

queuename <- sprintf("QUEUE_lrn:%s_tsk:%s", LEARNERNAME, TASKNAME)

data <- rbn.getData(TASKNAME)
lrn <- rbn.getLearner(LEARNERNAME)
paramtable <- rbn.compileParamTblConfigured()

was.error <- FALSE
repeat {
  seed <- rcon$INCR(queuename)
  if (!is.numeric(seed)) {
    was.error <- TRUE
    break
  }
  catf("----[%s] Evaluating seed %s", token, seed)
  points <- rbn.sampleEvalPoint(lrn, data$task, seed, paramtable)

  for (pt in points) {
    catf("----[%s] Evaluating point %s", token, pt)
    result <- rbn.evaluatePoint(lrn, pt, data)
    rbn.setWatchdogTimeout(600)  # ten minutes timeout to write result file

    rcon$SET(sprintf("RESULT_lrn:%s_tsk:%s_SD:%012.0f_val:%s", LEARNERNAME, TASKNAME, seed, pt),
      serialize(result, connection = NULL))
  }
  catf("----[%s] Done evaluating seed %s", token, seed)

  if (oneoff == "TRUE") {
    break
  }
}

if (was.error) {
  catf("----[%s] seed was bad. Current seed: %s. Integer overflow? Ending.", token, seed)
}
