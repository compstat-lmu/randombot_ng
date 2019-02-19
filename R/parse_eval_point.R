
# @param eval.point [character(1)] string to parse
# @param learner.object [Learner]: actual learner object.
# @param multiple [logical(1)] whether to accept multiple lines, divided by "\n"
# @return [list of named list] a list of points to evaluate if multiple is TRUE
#   otherwise [named list] point to evaluate
rbn.parseEvalPoint <- function(eval.point, learner.object, multiple = FALSE) {
  assertString(eval.point)

  eval.point <- gsub("^\\s+|\\s+$", "", eval.point)

  ps.orig <- getLearnerParamSet(learner.object)

  parsed <- lapply(strsplit(eval.point, "\n", fixed = TRUE)[[1]], function(ep) {
    value <- eval(parse(text = ep, keep.source = FALSE))
    for (param.name in names(value)) {
      if (param.name == "SUPEREVAL") {
        next
      }
      param.lrn <- ps.orig$pars[[param.name]]
      if (isDiscrete(param.lrn, include.logical = FALSE)) {
        pval <- value[[param.name]]
        assertSubset(pval, names(getValues(param.lrn)))
        if (isVector(param.lrn)) {
          newval <- getValues(param.lrn)[pval]
        } else {
          newval <- getValues(param.lrn)[[pval]]
        }
        value[[param.name]] <- newval
      }
    }
    value
  })
  if (!multiple) {
    if (length(parsed) != 1) {
      stop("Must give exactly one line")
    }
    parsed <- parsed[[1]]
  }
  parsed
}
