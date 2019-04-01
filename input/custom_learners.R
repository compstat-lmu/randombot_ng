
lapply(dir("learners", "\\.R$", full.names = TRUE), source, chdir = TRUE)

rbn.registerLearner("MODIFIER", function(lrn) {
  cpoFixFactors() %>>%
    cpoCbind(
        cpoImputeConstant("__MISSING__", affect.type = c("factor", "ordered")) %>>%
        cpoMultiplex(id = "num.impute",
          list(
              cpoImputeMean(affect.type = "numeric"),
              cpoImputeMedian(affect.type = "numeric"),
              cpoImputeHist(use.mids = FALSE, affect.type = "numeric")),
          selected.cpo = "impute.hist"),
        MISSING = cpoSelect(type = "numeric") %>>% cpoMissingIndicators()) %>>%
    cpoMaxFact(32) %>>%
    cpoDropConstants(abs.tol = 0) %>>% lrn
})


xgboost.constructor <- function() {
  lrn <- makeLearner("classif.xgboost")
  lrn$par.set$pars$nrounds$upper <- 6000
  # add dummy encode, xgboost can't handle factors otherwise
  cpoDummyEncode(reference.cat = TRUE, infixdot = TRUE) %>>% lrn
}

rbn.registerLearner("classif.xgboost.gblinear", xgboost.constructor)
rbn.registerLearner("classif.xgboost.gbtree", xgboost.constructor)
rbn.registerLearner("classif.xgboost.dart", xgboost.constructor)

rbn.registerLearner("classif.ranger", function() {
  lrn <- makeLearner("classif.ranger")
  lrn$par.set$pars$sample.fraction$lower <- 0.005
  lrn
})

rbn.registerLearner("classif.kerasff", function() {
  lrn <- makeLearner("classif.kerasff")
  lrn$par.set$pars$epochs$upper <- 1000
  lrn$par.set$pars$units_layer1$upper <- 2048
  lrn$par.set$pars$units_layer2$upper <- 2048
  lrn$par.set$pars$units_layer3$upper <- 2048
  lrn$par.set$pars$units_layer4$upper <- 2048
  cpoDummyEncode(reference.cat = TRUE, infixdot = TRUE) %>>% lrn
})


rbn.registerLearner("classif.svm.radial", function() {
  makeLearner("classif.svm")
})

rbn.registerLearner("classif.RcppHNSW", function() {
  lrn <- makeLearner("classif.RcppHNSW")
  lrn$par.set$pars$ef$lower = 8
  lrn$par.set$pars$ef_construction$lower = 8
  lrn$par.set$pars$M$lower = 2
  cpoDummyEncode(reference.cat = TRUE, infixdot = TRUE) %>>% lrn
})
