
lapply(dir("learners", "*.R"), source, chdir = TRUE)

rbn.registerLearner("MODIFIER", function(lrn) {
  cpoFixFactors() %>>%
    cpoCbind(
        cpoMultiplex(id = "num.impute",
          list(
              cpoImputeMean(),
              cpoImputeMedian(),
              cpoImputeHist()),
          selected.cpo = "impute.hist"),
        MISSING = cpoMissingIndicators(affect.type = "numeric")) %>>%
    cpoImputeConstant("__MISSING__", affect.type = c("factor", "ordered")) %>>%
    cpoMaxFact(32) %>>%
    cpoDropConstants(abs.tol = 0) %>>% lrn
})


# just a demonstration: hard limit classif.xgboost nrounds to 6000
rbn.registerLearner("classif.xgboost.1", function() {
  lrn <- makeLearner("classif.xgboost")
  lrn$par.set$pars$nrounds$upper <- 6000
  # add dummy encode, xgboost can't handle factors otherwise
  cpoDummyEncode(TRUE) %>>% lrn
})

