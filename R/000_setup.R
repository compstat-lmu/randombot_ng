
# load libraries, set up RNG

library("checkmate")
library("BBmisc")
library("mlr")
library("mlrCPO")
library("digest")

RNGversion("3.3")

configureMlr(show.info = TRUE,
  on.learner.error = "warn",
  on.learner.warning = "warn",
  show.learner.output = TRUE,
  on.error.dump = FALSE)

options(warn = 1)
