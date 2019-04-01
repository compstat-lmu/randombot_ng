rbn.getParamLengthOrOne <- function(param) {
  x <- getParamLengths(param)
  x[is.na(x)] <- 1
  x
}


# test that parameter table is good. This is "expensive" and should not be done
# in each individual evaluation, only whenever table (or the underlying system)
# changes.
#
# Checks that are done:
# - parameter given as "values" for discrete (or numeric when giving one val only),
#   "lower / upper" for numeric params
# - given parameter bounds are within learner's parameter bounds
# - condition evaluates to TRUE or FALSE for some values
# - 'requires' can be evaluated within parameter set and gives TRUE / FALSE
# - learner's ParamSet has no unfulfilled requires where given paramset doesn't
rbn.checkParamTbl <- function(table) {
  assertNumeric(table$proportion, lower = 0, finite = TRUE, any.missing = FALSE)
  assertTRUE(all(aggregate(table$proportion, by = table["learner"], FUN = sd)$x == 0))
  convertToParamType <- function(value, param, trafo) {
    if (isNumeric(param)) {
      val <- as.numeric(value)
      if (!is.null(trafo)) {
        val <- trafo(val)
      }
      if (length(val) == 1) {
        val <- rep_len(val, rbn.getParamLengthOrOne(param))
      }
      val
    } else if (isLogical(param)) {
      rep_len(as.logical(value), rbn.getParamLengthOrOne(param))
    } else if (isDiscrete(param, include.logical = FALSE)) {
      val <- getValues(param)[[value]]
      if (isVector(param)) {
        rep_len(list(val), rbn.getParamLengthOrOne(param))
      }
      val
    } else {
      stopf("Param of type %s not supported.", getParamTypes(param.lrn))
    }
  }
  checkParamLearner <- function(lrn, param.lrn, param.given) {
    assertCharacter(getParamIds(param.lrn), len = 1, any.missing = FALSE, pattern = "^[^][,\"\' \t\n=]*$")
    ptype <- gsub("vector$", "", param.lrn$type)
    if (isNumeric(param.lrn)) {
      if (length(param.given$values)) {  # for numeric params, the $values can hold a constant
        val <- as.numeric(param.given$values)
        assertNumeric(val, len = 1, any.missing = FALSE)  # ... but must then only hold one value
        assert(is.na(param.given$lower) && is.na(param.given$upper))
        param.given$lower <- param.given$upper <- val
      }
      if (is.null(param.given$trafo)) {
        if (isInteger(param.lrn)) {
          somevals <- c(param.given$lower,
            unique(round(runif(10, min = param.given$lower, max = param.given$upper))),
            param.given$upper)
        } else {
          somevals <- c(param.given$lower,
            runif(10, min = param.given$lower, param.given$upper),
            param.given$upper)
        }
        somevals <- lapply(somevals, rep_len, length.out = rbn.getParamLengthOrOne(param.lrn))
      } else {
        somevals <- c(param.given$lower,
          runif(10, min = param.given$lower, param.given$upper),
          param.given$upper)
        somevals <- lapply(sort(somevals), function(val) {
          val <- rep_len(val, rbn.getParamLengthOrOne(param.lrn))
          param.given$trafo(val)
        })
      }
    } else if (isDiscrete(param.lrn, include.logical = FALSE)) {
      assert(is.na(param.given$lower) && is.na(param.given$upper))
      assertCharacter(param.given$values, min.len = 1, any.missing = FALSE, unique = TRUE, pattern = "^[^][,\"\' \t\n=]*$")
      assertNull(param.given$trafo)
      pvals <- getValues(param.lrn)
      somevals <- param.given$values
      assertSubset(somevals, names(pvals))
      somevals <- pvals[somevals]
      if (isVector(param.lrn)) {
        somevals <- lapply(somevals, function(x) rep_len(list(x), rbn.getParamLengthOrOne(param.lrn)))
      }
    } else if (isLogical(param.lrn)) {
      assert(is.na(param.given$lower) && is.na(param.given$upper))
      somevals <- as.logical(param.given$values)
      assertNull(param.given$trafo)
      assertLogical(somevals, any.missing = FALSE, min.len = 1, unique = TRUE)
      if (isVector(param.lrn)) {
        somevals <- lapply(somevals, rep_len, length.out = rbn.getParamLengthOrOne(param.lrn))
      }
    } else {
      stopf("Param of type %s not supported.", getParamTypes(param.lrn))
    }
    assert(all(vlapply(somevals, isFeasible, par = param.lrn)))
  }

  for (lrn.name in unique(table$learner)) {
    lrn <- rbn.getLearner(lrn.name)
    subtbl <- table[table$learner == lrn.name, , drop = FALSE]
    assertSubset(subtbl$parameter, getParamIds(getParamSet(lrn)))

    fixed.values <- list()  # collect all fixed values (i.e. $values with one entry)
    arbitrary.values <- list()  # collect any value

    for (param.name in subtbl$parameter) {
      param.lrn <- getParamSet(lrn)$pars[[param.name]]
      entry <- which(subtbl$parameter == param.name)
      assert(length(entry) == 1)
      param.given <- lapply(subtbl, `[[`, entry)
      checkParamLearner(lrn, param.lrn, param.given)

      if (length(param.given$values) == 1) {
        fixed.values <- c(fixed.values,
          namedList(param.name,
            convertToParamType(param.given$values, param.lrn, param.given$trafo)))
      } else {
        if (isNumeric(param.lrn)) {
          val <- param.given$lower
        } else {
          val <- param.given$values[1]
        }
        arbitrary.values <- c(arbitrary.values,
          namedList(param.name,
            convertToParamType(val, param.lrn, param.given$trafo)))
      }
    }
    # the values that the learner "sees" include its default settings
    default.fixed.values <- insert(getDefaults(getParamSet(lrn)), fixed.values)
    true.requires <- getRequirements(getParamSet(lrn))
    for (param.name in subtbl$parameter) {
      param.lrn <- getParamSet(lrn)$pars[[param.name]]
      entry <- which(subtbl$parameter == param.name)
      param.given <- lapply(subtbl, `[[`, entry)
      if (hasRequires(param.lrn) && is.null(param.given$requires)) {
        # check that requirement of parameter is always fulfulled
        assert(isTRUE(eval(true.requires[[param.name]],
          envir = default.fixed.values, enclos = .GlobalEnv)))
      } else {
        if (!is.null(param.given$requires)) {
          reqeval <- eval(param.given$requires,
            envir = c(fixed.values, arbitrary.values), enclos = .GlobalEnv)
          assert(isTRUE(reqeval) || isFALSE(reqeval))
        }
      }
      condeval <- mapply(param.given$condition,
        MoreArgs = list(x = c(fixed.values, arbitrary.values)[[param.name]]),
        rep((1:10) * 100, 10), rep((1:10) * 100, each = 10))
      for (cx in condeval) {
        assert(isTRUE(cx) || isFALSE(cx))
      }
    }
  }
}
