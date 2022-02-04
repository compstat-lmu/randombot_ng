library(farff)
library(data.table)
library(OpenML)
library(testthat)
library(checkmate)
library(mlr)
library(mlrCPO)
source("R/get_learner.R")
source("input/learners/CPO_maxfact.R")
source("input/learners/RLearner_classif_rcpphnsw.R")


parse_lgl = function(lst) {
  lst = lapply(lst, function(x) {
    if (!is.na(x)) {
      if (x == "FALSE" || x == "TRUE")
        x = as.logical(x)
    }
    return(x)
  })
  Filter(Negate(is.na), lst)
}

replicate_algo = function(algo, n_repls = 20) {
  lrn = cpoFixFactors() %>>%
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
    cpoDropConstants(abs.tol = 0)

  if (algo == "classif.knn") {
    lrn2 = makeLearner("classif.RcppHNSW", predict.type = "prob")
    lrn2$par.set$pars$ef$lower = 8
    lrn2$par.set$pars$ef_construction$lower = 8
    lrn2$par.set$pars$M$lower = 2
    lrn = lrn %>>% cpoDummyEncode(reference.cat = TRUE, infixdot = TRUE) %>>% lrn2
  } else if (algo == "classif.xgboost") {
    lrn = lrn %>>%
     cpoDummyEncode(reference.cat = TRUE, infixdot = TRUE) %>>%
     makeLearner("classif.xgboost", predict.type = "prob")
  } else {
    lrn = lrn %>>% makeLearner(algo, predict.type = "prob")
  }

  # Choose a config
  if (algo == "classif.knn") algop = "classif.RcppHNSW"
  else algop = algo

  dt = data.table(farff::readARFF(paste0("../symbolicdefaults/data/rbv2_mlr_", algop, ".arff")))
  dt = dt[traintime < 10 & num.impute.selected.cpo != "impute.hist",]

  if (algo == "classif.svm")     dt = dt[kernel == "radial", ]
  if (algo == "classif.knn")     dt = dt[distance == "l2", ]
  if (algo == "classif.ranger")  dt = dt[splitrule == "gini" & replace == "TRUE", ]
  if (algo == "classif.xgboost") dt = dt[booster == "gbtree", ]

  rlst = lapply(seq_len(n_repls), function(x) {
    rw = sample(nrow(dt), 1)

    # Set configs hyperparameters
    hpnames = intersect(colnames(dt), names(getParamSet(lrn)$pars))
    lrn = setHyperPars(lrn, par.vals = parse_lgl(as.list(dt[rw, hpnames, with = FALSE])))

    # Run on task
    bmr = try({
      omltsk = getOMLTask(dt[rw, task_id])
      z = convertOMLTaskToMlr(omltsk, measures = mmce)
      benchmark(lrn, z$mlr.task, z$mlr.rin, measures = z$mlr.measures)
    })
    if (inherits(bmr, "try-error"))
      return(NULL)

    # Evaluate results
    result_repl = bmr$results[[1]][[1]]$aggr[["mmce.test.mean"]]
    result_rng  = dt[rw, perf.mmce]
    BBmisc::catf("Difference: %s", abs(result_repl - result_rng))
    c(result_repl, result_rng)
  })
  rdf = data.frame(do.call("rbind", rlst))
  colnames(rdf) = c("reproduced", "randombot")
  rdf$diff_abs = abs(rdf$reproduced - rdf$randombot)
  rdf$algo = algo
  fwrite(data.table(rdf), "reproduction_results.csv", append = TRUE)
  return(NULL)
}


algos = c("classif.ranger", "classif.rpart", "classif.glmnet", "classif.svm", "classif.knn", "classif.xgboost")
lapply(algos, replicate_algo)





rdf = fread("reproduction_results.csv", fill=TRUE)
rdf$diff_abs = rdf$diff_abs + 10^-17
library(ggplot2)
library(patchwork)

p1 = ggplot(rdf) +
  geom_boxplot(aes(y=diff_abs, x="1", fill=algo)) +
  scale_y_log10() +
  theme_minimal() +
  coord_flip() +
  facet_grid(rows=vars(algo), scales = "free") +
  guides(fill=FALSE) +
  ylab("Absolute difference in performances") +
  theme(
    axis.ticks.y = element_blank(),
    axis.title.y = element_blank(),
    axis.text.y = element_blank()
  ) +
  ggtitle("Log scaled x-axis", subtitle = "Vertical Bars: red:1e-3; blue:1e-1") +
  geom_hline(yintercept = 1e-3, color = "red") +
  geom_hline(yintercept = 1e-1, color = "blue")


p2 = ggplot(rdf) +
  geom_boxplot(aes(y=diff_abs, x="1", fill=algo)) +
  theme_minimal() +
  facet_grid(rows=vars(algo), scales = "free") +
  guides(fill=FALSE) +
  ylab("Absolute difference in performances") +
  theme(
    axis.ticks.y = element_blank(),
    axis.title.y = element_blank(),
    axis.text.y = element_blank()
  ) +
  coord_flip(ylim = c(1e-4, 1e-2)) +
  ggtitle("Zoomed in to [1e-4;1e-2]")

p = p1 + p2
ggsave(p, file = "reproduction_results.pdf")