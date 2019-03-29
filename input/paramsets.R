prob.classif.glmnet = 0.075
classif.glmnet = makeParamSet(
  makeNumericParam("alpha", lower = 0, upper = 1, default = 1),
  makeNumericVectorParam("s", len = 1L, lower = -10, upper = 10, default = 0, trafo = function(x) 2^x))


prob.classif.rpart = 0.10
classif.rpart = makeParamSet(
  makeNumericParam("cp", lower = 0, upper = 1, default = 0.01),
  makeIntegerParam("maxdepth", lower = 1, upper = 30, default = 30),
  makeIntegerParam("minbucket", lower = 1, upper = 60, default = 1),
  makeIntegerParam("minsplit", lower = 1, upper = 60, default = 20)
  # Open Question: Use *surrogate* params? => Only in case we do not generally impute all missings.
)

prob.classif.svm = 0.10
classif.svm = makeParamSet(
  makeDiscreteParam("kernel", values = c("linear", "polynomial", "radial")),
  makeNumericParam("cost", lower = -10, upper = 10, trafo = function(x) 2^x), # Discuss bounds -10, 3
  makeNumericParam("gamma", lower = -10, upper = 10, trafo = function(x) 2^x, requires = quote(kernel == "radial")), # Discuss bounds -10, 3
  makeIntegerParam("degree", lower = 2, upper = 5, requires = quote(kernel == "polynomial")),
  makeNumericParam("tolerance", lower = 0.001, upper = 1),
  makeLogicalParam("shrinking")
)
classif.svm.fixed_pars = list("fitted" = FALSE)

prob.classif.svm.radial = 0.075
classif.svm.radial = makeParamSet( # Only radial basis function kernel
  makeNumericParam("cost", lower = -10, upper = 10, trafo = function(x) 2^x), # Discuss bounds -10, 3
  makeNumericParam("gamma", lower = -10, upper = 10, trafo = function(x) 2^x), # Discuss bounds -10, 3
  makeNumericParam("tolerance", lower = -5, upper = -1, trafo = function(x) 2^x),
  makeLogicalParam("shrinking")
)
classif.svm.radial.fixed_pars = list("fitted" = FALSE)

prob.classif.ranger.pow = 0.15
# => See RLearner.classif.ranger.pow.R
classif.ranger.pow = makeParamSet(
  makeIntegerParam("num.trees", lower = 1, upper = 2000), # Discuss bounds to 1,500
  makeLogicalParam("replace"),
  makeNumericParam("sample.fraction", lower = 0.1, upper = 1),
  makeIntegerParam("mtry.power", lower = 0, upper = 1),
  makeDiscreteParam("respect.unordered.factors", values = c("ignore", "order", "partition")),
  makeIntegerParam("min.node.size", lower = 1, upper = 100),
  makeDiscreteParam("splitrule", values = c("gini", "extratrees")),
  makeIntegerParam("num.random.splits", lower = 1, upper = 100, default = 1L, requires = quote(splitrule == "extratrees"))) # No idea
classif.ranger.pow.fixed_pars = list("num.threads" = 1L)


prob.classif.xgboost.gblinear = 0.075
classif.xgboost.gblinear = makeParamSet(
  makeIntegerParam("nrounds", lower = 1, upper = 5000),
  makeNumericParam("lambda", lower = -10, upper = 10, trafo = function(x) 2^x),
  makeNumericParam("alpha", lower = -10, upper = 10, trafo = function(x) 2^x),
  makeNumericParam("subsample",lower = 0.1, upper = 1)
)
classif.xgboost.gblinear.fixed_pars = list("nthread" = 1L, booster = "gblinear")

prob.classif.xgboost.gbtree = 0.35
classif.xgboost.gbtree = makeParamSet(
  makeIntegerParam("nrounds", lower = 1, upper = 5000),
  makeNumericParam("eta",   lower = -10, upper = 0, trafo = function(x) 2^x),
  makeNumericParam("gamma", lower = -15, upper = 3, trafo = function(x) 2^x),
  makeNumericParam("lambda", lower = -10, upper = 10, trafo = function(x) 2^x),
  makeNumericParam("alpha", lower = -10, upper = 10, trafo = function(x) 2^x),
  makeNumericParam("subsample",lower = 0.1, upper = 1),
  makeIntegerParam("max_depth", lower = 1, upper = 15),
  makeNumericParam("min_child_weight",  lower = 0, upper = 7, trafo = function(x) 2^x),
  makeNumericParam("colsample_bytree",  lower = 0, upper = 1),
  makeNumericParam("colsample_bylevel", lower = 0, upper = 1)
  # makeDiscreteParam("tree_method", values = c("exact", "auto", "approx", "hist")), # CURRENTLY NOT IMPLEMENTED IN MLR
  )
classif.xgboost.gbtree.fixed_pars = list("nthread" = 1L, booster = "gbtree")

prob.classif.xgboost.dart = 0.075
classif.xgboost.dart = makeParamSet(
  makeIntegerParam("nrounds", lower = 1, upper = 5000),
  makeNumericParam("eta",   lower = -10, upper = 0, trafo = function(x) 2^x),
  makeNumericParam("gamma", lower = -15, upper = 3, trafo = function(x) 2^x),
  makeNumericParam("lambda", lower = -10, upper = 10, trafo = function(x) 2^x),
  makeNumericParam("alpha", lower = -10, upper = 10, trafo = function(x) 2^x),
  makeNumericParam("subsample",lower = 0.1, upper = 1),
  makeIntegerParam("max_depth", lower = 1, upper = 15),
  makeNumericParam("min_child_weight",  lower = 0, upper = 7, trafo = function(x) 2^x),
  makeNumericParam("colsample_bytree",  lower = 0, upper = 1),
  makeNumericParam("colsample_bylevel", lower = 0, upper = 1),
  makeNumericParam("rate_drop", lower = 0, upper = 1),
  makeNumericParam("skip_drop", lower =  0, upper = 1))
classif.xgboost.dart.fixed_pars = list("nthread" = 1L, booster = "dart")

# Leave this out for now as there is no benefit over glmnet (LiblineaR svm can not do probs)
# # => See RLearner.classif.LiblineaR.R
# classif.LiblineaR = makeParamSet(
#   makeDiscreteParam(id = "type", default = 0L, values = 0:7),
#   makeNumericParam(id = "cost", default = 10, lower = -10, upper = 10, trafo = function(x) 2^x),
#   makeNumericParam(id = "epsilon", default = log2(0.01), lower = -12, upper = 0, trafo = function(x) 2^x),
#   makeLogicalParam(id = "bias", default = TRUE)
# )

prob.classif.RcppHNSW = 0.075
classif.RcppHNSW = makeParamSet(
  makeIntegerParam(id = "k", lower = 1L, upper = 50),
  makeDiscreteParam(id = "distance", values = c("l2", "cosine", "ip"), default = "l2"),
  makeIntegerParam(id = "M", lower = 18, upper = 50),
  makeNumericParam(id = "ef", lower = 4, upper = 8, trafo = function(x) round(2^x)),
  makeNumericParam(id = "ef_construction", lower = 4, upper = 8, trafo = function(x) round(2^x))
)

prob.classif.kerasff = 0.075
classif.kerasff = makeParamSet(
      makeIntegerParam(id = "epochs", lower = 10L, upper = 100L),
      makeDiscreteParam(id = "optimizer",
        values = c("sgd", "rmsprop", "adam", "nadam")),
      makeNumericParam(id = "lr", lower = -8, upper = 0, trafo = function(x) 5^x),
      makeNumericParam(id = "decay", lower = -8, upper = 0, trafo = function(x) 5^x),
      makeNumericParam(id = "momentum", lower = -8, upper = 0,trafo = function(x) 5^x,
        requires = quote(optimizer == "sgd")),
      makeNumericParam(id = "rho", lower = -8, upper = 0,trafo = function(x) 5^x,
        requires = quote(optimizer == "rmsprop")),
      makeNumericParam(id = "beta_1", lower = -8, upper = 0, trafo = function(x) 1 - 5^x,
        requires = quote(optimizer %in% c("adam", "nadam"))),
      makeNumericParam(id = "beta_2", lower = -8, upper = 0, trafo = function(x) 1 - 5^x,
        requires = quote(optimizer %in% c("adam", "nadam"))),
      makeIntegerParam(id = "layers", lower = 1L, upper = 4L),
      makeDiscreteParam(id = "batchnorm_dropout", values = c("batchnorm", "dropout", "none")),
      makeNumericParam(id = "input_dropout_rate", lower = 0, upper = 1, requires = quote(batchnorm_dropout == "dropout")),
      makeNumericParam(id = "dropout_rate", lower = 0, upper = 1, requires = quote(batchnorm_dropout == "dropout")),
      # Neurons / Layers
      makeIntegerParam(id = "units_layer1", lower = 10L, upper = 512),
      makeIntegerParam(id = "units_layer2", lower = 10L, upper = 512, requires = quote(layers >= 2)),
      makeIntegerParam(id = "units_layer3", lower = 10L, upper = 512, requires = quote(layers >= 3)),
      makeIntegerParam(id = "units_layer4", lower = 10L, upper = 512, requires = quote(layers >= 4)),
      # Activations
      makeDiscreteParam(id = "act_layer",
        values = c("elu", "relu", "selu", "tanh", "sigmoid")),
      # Initializers
      makeDiscreteParam(id = "init_layer",
        values = c("glorot_normal", "glorot_uniform", "he_normal", "he_uniform")),
      # Regularizers
      makeNumericParam(id = "l1_reg_layer",
        lower = -10, upper = -1, trafo = function(x) 5^x),
      makeNumericParam(id = "l2_reg_layer",
        lower = -10, upper = -1, trafo = function(x) 5^x),
      makeLogicalParam(id = "learning_rate_scheduler", default = FALSE)
    )
classif.kerasff.fixed_pars = list(early_stopping_patience = 0L, validation_split = 0, nthread = 1L, init_seed = 1444L)


preproc.pipeline <- pSS(
  num.impute.selected.cpo: discrete [impute.mean, impute.median, impute.hist]  # numeric feature imputation to use
)
