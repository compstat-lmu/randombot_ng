# evaluate all points for a given TASKNAME and LEARNERNAME,
# skipping in increments of PERCPU_STEPSIZE
# reading progress from and writing it back to PROGRESSFILE

token <- Sys.getenv("TOKEN")
seedoffset <- as.integer(Sys.getenv("STARTSEED")) - 1L
stopifnot(is.finite(seedoffset))
oneoff <- Sys.getenv("ONEOFF") == "TRUE"
stresstest <- Sys.getenv("STRESSTEST") == "TRUE"

suppressPackageStartupMessages({
  library("BBmisc")
  library("redux")
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

r.host <- Sys.getenv("REDISHOST")
r.port <- Sys.getenv("REDISPORT")
r.pass <- Sys.getenv("REDISPW")
r.port <- as.integer(r.port)

rcon <- NULL
catf("----[%s] Connecting to redis %s:%s", token, r.host, r.port)
rcon <- hiredis(host = r.host, port = r.port, password = r.pass)

LEARNERNAME <- Sys.getenv("LEARNERNAME")
TASKNAME <- Sys.getenv("TASKNAME")

queuename <- sprintf("QUEUE_lrn:%s_tsk:%s_offset:%s", LEARNERNAME, TASKNAME, seedoffset)

if (stresstest) {
  LEARNERNAME <- "classif.rpart"
  TASKNAME <- "LED.display.domain.7digit.40496"
}

data <- rbn.getData(TASKNAME)
lrn <- rbn.getLearner(LEARNERNAME)

paramtable <- rbn.compileParamTblConfigured()

was.error <- FALSE
repeat {
  if (stresstest) {
    preseed <- 1
  } else {
    preseed <- rcon$INCR(queuename)
  }
  seed <- as.integer(preseed + seedoffset)
  if (!is.numeric(seed) || !is.finite(seed) ||
      !is.numeric(preseed) || !is.finite(preseed) ||
      seed < 0) {
    was.error <- TRUE
    break
  }

  catf("----[%s] Evaluating seed %s", token, seed)
  points <- rbn.sampleEvalPoint(lrn, data$task, seed, paramtable)

  for (pt in points) {
    catf("----[%s] Evaluating point %s", token, pt)
    result <- rbn.evaluatePoint(lrn, pt, data)
    rbn.setWatchdogTimeout(600)  # ten minutes timeout to write result file

    result$METADATA <- list(learner = LEARNERNAME, task = TASKNAME, seed = seed, point = pt)
    repeat {
      rcon$LPUSH("RESULTS", serialize(result, connection = NULL))
      if (!stresstest || oneoff) {
        break
      }
    }
  }
  catf("----[%s] Done evaluating seed %s", token, seed)

  if (oneoff) {
    break
  }
}

if (was.error) {
  catf("----[%s] seed was bad. Current seed: %s (%s before offset). Integer overflow? Ending.",
    token, seed, preseed)
}
