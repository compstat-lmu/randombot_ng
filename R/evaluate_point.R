
# Evaluate learner on data at point
#
# This does not save the result or redirect the output!
#
# @param learner.object [Learner] Learner to evaluate
# @param point.string [character(1)] parameter values, also with SUPEREVAL entry TRUE/FALSE, as given by rbn.sampleEvalPoint
# @param data [list(Task, ResamplingInstance)] Task '$task', resampling instances '$resampling'
#   and '$super.resampling'
# @return [ResampleResult]
rbn.evaluatePoint <- function(learner.object, point.string, data, seed) {
  point.value <- rbn.parseEvalPoint(point.string, learner.object)

  supereval <- point.value$SUPEREVAL
  point.value$SUPEREVAL <- NULL
  learner.object <- setHyperPars(learner.object, par.vals = point.value)
  assertFlag(supereval)
  assertSubset(c("resampling", "super.resampling"), names(data))

  if (supereval) {
    resampling <- data$super.resampling
    set.seed(seed)
  } else {
    resampling <- data$resampling
    set.seed(seed)
    set.seed(floor(runif(1, 0, 2^31)))
  }

  catf("!!--- BEGIN Evaluating Point: '%s' ---!!", point.string)
  on.exit(catf("!!--- EXITING eval function of point: '%s' ---!!", point.string))

  res <- resample(learner = learner.object, task = data$task, resampling = resampling,
    measures = list(timetrain, timepredict), models = FALSE, keep.pred = TRUE)
  catf("!!--- DONE Evaluating Point: '%s' ---!!", point.string)
  res
}
