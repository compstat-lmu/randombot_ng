

rbn.registerLearner("MODIFIER", function(lrn) {
  cpoImpute(classes = list(
      numeric = imputeHist(),
      factor = imputeConstant("__MISSING__")),
    recode.factor.levels = TRUE) %>>% lrn
})


# just a demonstration
rbn.registerLearner("classif.svm", function() {
  cpoCbind(NULLCPO, cpoSelect("numeric") %>>% cpoPca(rank = 3)) %>>%
    makeLearner("classif.svm")
})
