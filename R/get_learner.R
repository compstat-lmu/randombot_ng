library("checkmate")
library("mlr")

if (!exists(".custom.learner.register")) {
  .custom.learner.register <- new.env(parent = emptyenv())
  .custom.learner.register$MODIFIER = identity
}

# get a learner that was previously registered with `rbn.registerLearner`.
# Learner is automatically wrapped as a Watchdog Learner
# @param learner [character(1)] the name of the custom learner to get
# @return [Learner]
rbn.getCustomLearner <- function(learner) {
  assertString(learner)
  makeWatchedLearner(.custom.learner.register[[learner]](), rbn.getSetting("RESAMPLINGTIMEOUTS"), TRUE)
}

# register a custom learner (using a creator function)
# @param learner [character(1)] name which should be used to retrieve the learner
# @param creator [function] function with no arguments that returns a [Learner]
rbn.registerLearner <- function(learner, creator) {
  assertString(learner)
  assertFunction(creator, nargs = as.integer(learner == "MODIFIER"))
  .custom.learner.register[[learner]] <- creator
}

# get a learner by name; may be custom or mlr learner; custom is preferred.
# @param learner [character(1)] name of the learner to get.
# @return [Learner]
rbn.getLearner <- function(learner) {
  lrn = rbn.getCustomLearner(learner) %??%
    makeLearner(learner, predict.type = "prob")
  rbn.getCustomLearner("MODIFIER")(lrn)
}

