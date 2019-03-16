

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


# just a demonstration
rbn.registerLearner("classif.svm", function() {
  cpoCbind(NULLCPO, cpoSelect("numeric") %>>% cpoPca(rank = 3)) %>>%
    makeLearner("classif.svm")
})

rbn.registerLearner("classif.xgboost", function() {
  cpoDummyEncode(TRUE) %>>% makeLearner("classif.xgboost")
})
