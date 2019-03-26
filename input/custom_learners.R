
lapply(dir("learners", "\\.R$", full.names = TRUE), source, chdir = TRUE)

rbn.registerLearner("MODIFIER", function(lrn) {
  cpoFixFactors() %>>%
    cpoCbind(
        cpoMultiplex(id = "num.impute",
          list(
              cpoImputeMean(affect.type = "numeric"),
              cpoImputeMedian(affect.type = "numeric"),
              cpoImputeHist(affect.type = "numeric")),
          selected.cpo = "impute.hist"),
        MISSING = cpoMissingIndicators(affect.type = "numeric")) %>>%
    cpoImputeConstant("__MISSING__", affect.type = c("factor", "ordered")) %>>%
    cpoMaxFact(32) %>>%
    cpoDropConstants(abs.tol = 0) %>>% lrn
})


xgboost.constructor <- function() {
  lrn <- makeLearner("classif.xgboost")
  lrn$par.set$pars$nrounds$upper <- 6000
  # add dummy encode, xgboost can't handle factors otherwise
  cpoDummyEncode(TRUE) %>>% lrn
}

rbn.registerLearner("classif.xgboost.gblinear", xgboost.constructor)
rbn.registerLearner("classif.xgboost.gbtree", xgboost.constructor)
rbn.registerLearner("classif.xgboost.dart", xgboost.constructor)

rbn.registerLearner("classif.svm.radial", function() {
  makeLearner("classif.svm")
})

rbn.registerLearner("classif.RcppHNSW", function() {
  lrn <- makeLearner("classif.RcppHNSW")
  cpoDummyEncode(TRUE) %>>% lrn
})
