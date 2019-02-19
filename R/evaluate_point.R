

# evaluate point with learner object and data
# learner.object [Learner] Learner to evaluate
# point.value [named list] list of parameter values, also with SUPEREVAL entry TRUE/FALSE
# data [list(Task, ResamplingInstance)] Task '$task', resampling instances '$resampling'
#   and '$super.resampling'
rbn.evaluatePoint <- function(learner.object, point.string, data) {
  point.value <- rbn.parseEvalPoint(point.string, learner.object)

  supereval <- point.value$SUPEREVAL
  point.value$SUPEREVAL <- NULL
  assertFlag(supereval)
  assertSubset(c("resampling", "super.resampling"), names(data))

  if (supereval) {
    resampling <- data$super.resampling
    set.seed(1)
  } else {
    resampling <- data$resampling
    set.seed(2)
  }

  catf("!!--- BEGIN Evaluating Point: '%s' ---!!", point.string)
  on.exit(catf("!!--- EXITING eval function of point: '%s' ---!!", point.string))

  res <- resample(learner = learner.object, task = data$task, resampling = resampling,
    measures = list(timetrain, timepredict), models = FALSE, keep.pred = TRUE,
    show.info = TRUE)
  catf("!!--- DONE Evaluating Point: '%s' ---!!", point.string)
  res
}
