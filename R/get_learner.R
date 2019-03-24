library("checkmate")
library("mlr")

if (!exists(".custom.learner.register")) {
  .custom.learner.register <- new.env(parent = emptyenv())
  .custom.learner.register$MODIFIER = identity
}

# get a learner constructor that was previously registered with
# `rbn.registerLearner` or NULL
# @param learner [character(1)] the name of the custom learner to get
# @return [Learner]
rbn.getCustomLearnerConstructor <- function(learner) {
  assertString(learner)
  .custom.learner.register[[learner]]
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
# Learner is automatically wrapped by MODIFIER and Watchdog Learner
# @param learner [character(1)] name of the learner to get.
# @return [Learner]
rbn.getLearner <- function(learner) {
  assertString(learner)
  lrn <- rbn.getCustomLearnerConstructor(learner) %??%
    function() makeLearner(learner)
  lrn <- suppressWarnings(setPredictType(lrn(), "prob"))
  wrapper <- rbn.getCustomLearnerConstructor("MODIFIER")
  if (!is.null(wrapper)) {
    lrn <- wrapper(lrn)
  }
  lrn <- makeWatchedLearner(lrn, rbn.getSetting("RESAMPLINGTIMEOUTS"), TRUE)
  lrn$id <- learner
  lrn
}

