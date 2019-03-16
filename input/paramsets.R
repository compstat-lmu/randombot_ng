classif.glmnet = makeParamSet(
  makeNumericParam("alpha", lower = 0, upper = 1, default = 1),
  makeNumericVectorParam("lambda", len = 1L, lower = -10, upper = 10, default = 0, trafo = function(x) 2^x))
)

classif.rpart = makeParamSet(
  makeNumericParam("cp", lower = 0, upper = 1, default = 0.01),
  makeIntegerParam("maxdepth", lower = 1, upper = 30, default = 30),
  makeIntegerParam("minbucket", lower = 1, upper = 60, default = 1),
  makeIntegerParam("minsplit", lower = 1, upper = 60, default = 20)
  # Open Question: Use *surrogate* params? => Only in case we do not generally impute all missings.
)


classif.svm = makeParamSet(
  makeDiscreteParam("kernel", values = c("linear", "polynomial", "radial")),
  makeNumericParam("cost", lower = -10, upper = 10, trafo = function(x) 2^x), # Discuss bounds -10, 3
  makeNumericParam("gamma", lower = -10, upper = 10, trafo = function(x) 2^x, requires = quote(kernel == "radial")), # Discuss bounds -10, 3
  makeIntegerParam("degree", lower = 2, upper = 5, requires = quote(kernel == "polynomial")),
  makeNumericParam("tolerance", lower = 0.001, upper = 1),
  makeLogicalParam("shrinking")
)
classif.svm = makeParamSet( # Only radial basis function kernel
  makeNumericParam("cost", lower = -10, upper = 10, trafo = function(x) 2^x), # Discuss bounds -10, 3
  makeNumericParam("gamma", lower = -10, upper = 10, trafo = function(x) 2^x, requires = quote(kernel == "radial")), # Discuss bounds -10, 3
  makeNumericParam("tolerance", lower = -5, upper = -1, trafo = function(x) 2^x),
  makeLogicalParam("shrinking")
)

# => See RLearner.classif.ranger.pow.R
classif.ranger.pow = makeParamSet(
  makeIntegerParam("num.trees", lower = 1, upper = 2000), # Discuss bounds to 1,500
  makeLogicalParam("replace"),
  makeNumericParam("sample.fraction", lower = 0.1, upper = 1),
  makeIntegerParam("mtry.power", lower = 0, upper = 1),
  makeDiscreteParam("respect.unordered.factors", values = c("ignore", "order", "partition")),
  makeIntegerParam("min.node.size", lower = 1, upper = 100),
  makeDiscreteParam("splitrule", values = c("gini", "extratrees")),
  makeIntegerParam("num.random.splits", lower = 1, upper = 100, default = 1L, requires = quote(splitrule == "extratrees") # No idea
)
classif.ranger.pow.fixed_pars = list("num.threads" = 1L)


classif.xgboost = makeParamSet(
  makeIntegerParam("nrounds", lower = 1, upper = 5000),
  makeDiscreteParam("booster", values = c("gbtree", "gblinear", "dart")),
  makeNumericParam("eta",   lower = -10, upper = 0, requires = quote(booster %in% c("dart", "gbtree")), trafo = function(x) 2^x),
  makeNumericParam("gamma", lower = -15, upper = 3, requires = quote(booster %in% c("dart", "gbtree")), trafo = function(x) 2^x),
  makeNumericParam("lambda", lower = -10, upper = 10, trafo = function(x) 2^x),
  makeNumericParam("alpha", lower = -10, upper = 10, trafo = function(x) 2^x),
  makeNumericParam("subsample",lower = 0.1, upper = 1),
  makeIntegerParam("max_depth", lower = 1, upper = 15,        requires = quote(booster %in% c("dart", "gbtree"))),
  makeNumericParam("min_child_weight",  lower = 0, upper = 7, requires = quote(booster %in% c("dart", "gbtree")), trafo = function(x) 2^x),
  makeNumericParam("colsample_bytree",  lower = 0, upper = 1, requires = quote(booster %in% c("dart", "gbtree"))),
  makeNumericParam("colsample_bylevel", lower = 0, upper = 1, requires = quote(booster %in% c("dart", "gbtree"))),
  # makeDiscreteParam("tree_method", values = c("exact", "auto", "approx", "hist")), # CURRENTLY NOT IMPLEMENTED IN MLR
  makeNumericParam("rate_drop", lower = 0, upper = 1, requires = quote(booster == "dart")),
  makeNumericParam("skip_drop", lower =  0, upper = 1, requires = quote(booster == "dart")))
classif.xgboost.fixed_pars = list("nthread" = 1L)


# => See RLearner.classif.LiblineaR.R
classif.LiblineaR = makeParamSet(
  makeDiscreteParam(id = "type", default = 0L, values = 0:7),
  makeNumericParam(id = "cost", default = 10, lower = -10, upper = 10, trafo = function(x) 2^x),
  makeNumericParam(id = "epsilon", default = 0.01, lower = -12, upper = 0, trafo = function(x) 2^x),
  makeLogicalParam(id = "bias", default = TRUE)
)
