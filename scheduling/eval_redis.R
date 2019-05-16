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

queuename <- sprintf("QUEUE_lrn:%s_tsk:%s_offset:%s", LEARNERNAME, TASKNAME, seedoffset + 1L)

if (stresstest) {
  LEARNERNAME <- "classif.rpart"
  TASKNAME <- "LED.display.domain.7digit.40496"
}

data <- rbn.getData(TASKNAME)
lrn <- rbn.getLearner(LEARNERNAME)

paramtable <- rbn.compileParamTblConfigured()

was.error <- FALSE
repeat {
  time0 <- as.numeric(Sys.time())
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
  time1 <- as.numeric(Sys.time())

  catf("----[%s] Evaluating seed %s", token, seed)
  points <- rbn.sampleEvalPoint(lrn, data$task, seed, paramtable)
  time2 <- as.numeric(Sys.time())

  catf("----[%s] Timing (setup): seed retrieve [s]: %s, sample point [s]: %s",
    token, time1 - time0, time2 - time1)

  iter <- 0
  for (pt in points) {
    catf("----[%s] %s Evaluating point %s", token, Sys.time(), pt)
    time3 <- as.numeric(Sys.time())
    result <- rbn.evaluatePoint(lrn, pt, data)
    rbn.setWatchdogTimeout(600)  # ten minutes timeout to write result file
    time4 <- as.numeric(Sys.time())
    result$METADATA <- list(learner = LEARNERNAME, task = TASKNAME, seed = seed, point = pt)
    if (stresstest) repeat {
      result$METADATA$seed <- round(runif(1, 1, 2^31))
      rcon$LPUSH("RESULTS", serialize(result, connection = NULL))
      if (oneoff) break
    } else {
      rcon$LPUSH("RESULTS", serialize(result, connection = NULL))
    }
    time5 <- as.numeric(Sys.time())
    catf("----[%s] Timing (eval %s): Evaluation [s]: %s, Sending result [s]: %s",
      token, iter, time4 - time3, time5 - time4)
    iter <- iter + 1
  }
  catf("----[%s] %s Done evaluating seed %s", token, Sys.time(), seed)

  if (oneoff) {
    break
  }
}

if (was.error) {
  catf("----[%s] seed was bad. Current seed: %s (%s before offset). Integer overflow? Ending.",
    token, seed, preseed)
}
