prob.classif.glmnet = 8
prob.classif.rpart = 3
prob.classif.svm = 60
prob.classif.svm.radial = 21
prob.classif.ranger.pow = 35
prob.classif.xgboost.gblinear = 32
prob.classif.xgboost.gbtree = 177
prob.classif.xgboost.dart = 150
prob.classif.RcppHNSW = 4
prob.classif.kerasff = 47


classif.glmnet = makeParamSet(
  # alpha: [-Inf;0] L1, [1; Inf] L2, [0;1] elasticnet (15/15/70)% approx.
  makeNumericParam("alpha", lower = 0, upper = 1, default = 1, trafo = function(x) max(0, min(1, x))),
  makeNumericVectorParam("s", len = 1L, lower = -10, upper = 10, default = 0, trafo = function(x) 2^x)
)

classif.rpart = makeParamSet(
  makeNumericParam("cp", lower = -10, upper = 0, default = 0.01, trafo = function(x) 2^x),
  makeIntegerParam("maxdepth", lower = 1, upper = 30, default = 30),
  makeIntegerParam("minbucket", lower = 1, upper = 100, default = 1),
  makeIntegerParam("minsplit", lower = 1, upper = 100, default = 20)
  # Open Question: Use *surrogate* params? => Only in case we do not generally impute all missings.
)

classif.svm = makeParamSet(
  makeDiscreteParam("kernel", values = c("linear", "polynomial", "radial")),
  makeNumericParam("cost", lower = -12, upper = 12, trafo = function(x) 2^x),
  makeNumericParam("gamma", lower = -12, upper = 12, trafo = function(x) 2^x, requires = quote(kernel == "radial")), # Discuss bounds -10, 3
  makeIntegerParam("degree", lower = 2, upper = 5, requires = quote(kernel == "polynomial")),
  makeNumericParam("tolerance", lower = -12, upper = -3, trafo = function(x) 2^x),
  makeLogicalParam("shrinking")
)
classif.svm.fixed_pars = list("fitted" = FALSE)

classif.svm.radial = makeParamSet( # Only radial basis function kernel
  makeNumericParam("cost", lower = -12, upper = 12, trafo = function(x) 2^x),
  makeNumericParam("gamma", lower = -12, upper = 12, trafo = function(x) 2^x),
  makeNumericParam("tolerance", lower = -12, upper = -3, trafo = function(x) 2^x),
  makeLogicalParam("shrinking")
)
classif.svm.radial.fixed_pars = list("fitted" = FALSE)

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

classif.xgboost.gblinear = makeParamSet(
  makeIntegerParam("nrounds", lower = 3, upper = 11, trafo = function(x) round(2^x)),
  makeNumericParam("lambda", lower = -10, upper = 10, trafo = function(x) 2^x),
  makeNumericParam("alpha", lower = -10, upper = 10, trafo = function(x) 2^x),
  makeNumericParam("subsample",lower = 0.1, upper = 1)
)
classif.xgboost.gblinear.fixed_pars = list("nthread" = 1L, booster = "gblinear")

classif.xgboost.gbtree = makeParamSet(
makeIntegerParam("nrounds", lower = 3, upper = 11, trafo = function(x) round(2^x)),
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

classif.xgboost.dart = makeParamSet(
  makeIntegerParam("nrounds", lower = 3, upper = 11, trafo = function(x) round(2^x)),
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


classif.RcppHNSW = makeParamSet(
  makeIntegerParam(id = "k", lower = 1L, upper = 50),
  makeDiscreteParam(id = "distance", values = c("l2", "cosine", "ip"), default = "l2"),
  makeIntegerParam(id = "M", lower = 18, upper = 50),
  makeNumericParam(id = "ef", lower = 4, upper = 8, trafo = function(x) round(2^x)),
  makeNumericParam(id = "ef_construction", lower = 4, upper = 8, trafo = function(x) round(2^x))
)

classif.kerasff = makeParamSet(
      makeNumericParam(id = "epochs", lower = 3, upper = 7, trafo = function(x) round(2^x)),
      makeDiscreteParam(id = "optimizer",
        values = c("sgd", "rmsprop", "adam")),
      makeNumericParam(id = "lr", lower = -5, upper = 0, trafo = function(x) 5^x),
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
      makeIntegerParam(id = "units_layer1", lower = 3L, upper = 9,  trafo = function(x) round(2^x)),
      makeIntegerParam(id = "units_layer2", lower = 3L, upper = 9, trafo = function(x) round(2^x), requires = quote(layers >= 2)),
      makeIntegerParam(id = "units_layer3", lower = 3L, upper = 9, trafo = function(x) round(2^x), requires = quote(layers >= 3)),
      makeIntegerParam(id = "units_layer4", lower = 3L, upper = 9, trafo = function(x) round(2^x), requires = quote(layers >= 4)),
      # Activations
      makeDiscreteParam(id = "act_layer", values = c("relu", "selu", "tanh")),
      # Initializers
      makeDiscreteParam(id = "init_layer",
        values = c("glorot_normal", "glorot_uniform", "he_normal", "he_uniform")),
      # Regularizers
      makeNumericParam(id = "l1_reg_layer",
        lower = -10, upper = -1, trafo = function(x) 5^x),
      makeNumericParam(id = "l2_reg_layer",
        lower = -10, upper = -1, trafo = function(x) 5^x),
      makeLogicalParam(id = "learning_rate_scheduler", default = FALSE),
      makeDiscreteParam(id = "init_seed", values = c(1L, 11L, 101L, 131L, 499L))
    )
classif.kerasff.fixed_pars = list(early_stopping_patience = 0L, validation_split = 0, nthread = 1L)

preproc.pipeline <- pSS(
  num.impute.selected.cpo: discrete [impute.mean, impute.median, impute.hist]  # numeric feature imputation to use
)
