
# @param learner.name [character(1)]: name of learner, as it is found in paramtbl
# @param learner.object [Learner]: actual learner object. Could be gotten from
#   rbn.getLearner, but we don't waste time with that
# @param data [Task] The dataset. Used to check paramtbl 'condition's
# @param paramtbl [data.frame] parameter table generated with rbn.compileParamTbl
# @return [character(1)] (!!!) a single string that can be parsed with
#   `rbn.parseEvalPoint()`
rbn.sampleEvalPoint <- function(learner.name, learner.object, data, seed, paramtbl) {
  assertString(learner.name)
  stop("TODO")

}

# test that parameter table is good. This is "expensive" and should not be done
# in each individual evaluation, only whenever table (or the underlying system)
# changes.
#
# Checks that are done:
# - parameter given as "values" for discrete (or numeric when giving one val only),
#   "lower / upper" for numeric params
# - given parameter bounds are within learner's parameter bounds
# - trafo is monotonic
# - condition evaluates to TRUE or FALSE for some values
# - 'requires' can be evaluated within parameter set and gives TRUE / FALSE
# - learner's ParamSet has no unfulfilled requires where given paramset doesn't
rbn.checkParamTbl <- function(table) {

  checkParamLearner <- function(lrn, param.lrn, param.given) {
    assertDataFrame(param.given, nrows = 1)  # parameter only named once
    ptype <- gsub("vector$", "", param.lrn$type)
    if (ptype %in% c("integer", "numeric")) {
      if (length(param.given$values)) {
        val <- as.numeric(param.given$values)
        assertNumeric(val, len = 1, any.missing = FALSE)
        assert(is.na(param.given$lower) && is.na(param.given$upper))
        param.given$lower <- param.given$upper <- val
      }
      if (is.null(param.given$trafo)) {
        if (ptype == "integer") {
          somevals <- c(param.given$lower,
            unique(round(runif(10, min = param.given$lower, max = param.given$upper))),
            param.given$upper)
        } else {
          somevals <- c(param.given$lower, runif(10, min = param.given$lower, param.given$upper), param.given$upper)
        }

      }
    }


  }

  for (lrn.name in unique(table$learner)) {
    lrn <- rbn.getLearner(lrn.name)
    subtbl <- table[table$learner == lrn.name, ]
    assertSubset(subtbl$parameter, getParamIds(getParamSet(lrn)))
    for (param.name in subtbl$parameter) {
      checkParamLearner(lrn, getParamSet(lrn)$pars[[parameter]], subtbl[subtbl$parameter == param.name])
    }
  }
}

# compile parameter table (turn strings into expressions etc.)
# @param table [data.frame | character(1)] either a data.table, or a file name that
#   can be read with read.csv
# @param ... additional arguments to read.csv if `table` is a [character(1)].
rbn.compileParamTbl <- function(table, ...) {
  required.names <- c("learner", "parameter", "values", "lower", "upper", "trafo",
    "requires", "condition")

  assert(
      checkDataFrame(table),
      checkString(table)
  )

  if (testString(table)) {
    table <- read.csv(table, ...)
    assertDataFrame(table)
  }
  assertNames(colnames(table), permutation.of = required.names)
  table <- table[required.names]

  table$learner <- as.character(table$learner)  # learner name, as in rbn.getLearner

  table$parameter <- as.character(table$parameter) # parameter name

  table$values <- as.character(table$values)  # if discrete: list of value names
  table$values[is.na(table$values)] <- ""
  table$values <- gsub("^\\s+|\\s+$", "", table$values)
  table$values <- strsplit(table$values, ",\\s*")

  table$lower <- as.numeric(table$lower)
  table$upper <- as.numeric(table$upper)

  table$trafo <- lapply(as.character(table$trafo), function(x) {
    if (!is.na(x) && !grepl("^\\s*$", x)) {
      eval(parse(text = sprintf("function(x) { %s }", x)))
    }
  })

  table$requires <- lapply(as.character(table$requires), function(x) {
    if (!is.na(x) && !grepl("^\\s*$", x)) {
      asQuoted(x)
    }
  })

  table$condition <- lapply(as.character(table$condition), function(x) {
    if (!is.na(x) && !grepl("^\\s*$", x)) {
      eval(parse(text = sprintf("function(x, n, p) { %s }", x)))
    } else {
      function(x, n, p) TRUE
    }
  })
  table
}
