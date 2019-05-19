
# load libraries, set up RNG

suppressPackageStartupMessages({
  library("checkmate")
  library("BBmisc")
  library("mlr")
  library("mlrCPO")
  library("digest")
})

RNGversion("3.3")

configureMlr(
  on.learner.error = "quiet",
  on.learner.warning = "quiet",
  show.learner.output = FALSE,
  show.info = FALSE,
  on.error.dump = FALSE)

options(warn = 1)
