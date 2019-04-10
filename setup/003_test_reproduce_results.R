# Reproduce stuff from old randombot

library(OpenML)
library(BBmisc)
runs = listOMLRuns(tag="mlrRandomBot", limit = 5000)
runs = runs[runs$flow.id == 5906,]

reproduceFromRun = function(run.id) {
  r = getOMLRun(run.id)
  flow = getOMLFlow(r$flow.id)
  task = getOMLTask(r$task.id)
  pars = getOMLRunParList(r)
  out = runTaskFlow(
    task = task,
    par.list = pars,
    flow =  flow,
    seed = 1L)
  old_acc = r$output.data$evaluations[r$output.data$evaluations$name == "predictive_accuracy", "value"][1]
  new_acc = out$bmr$results[[1]][[1]]$aggr["acc.test.join"]
  catf("Task: %s, Learner %s", r$task.id, r$flow.id)
  catf("Params: %s", paste(data.frame(pars)$name, data.frame(pars)$value, sep = ":", collapse = ","))
  catf("Reproduced MMCE: %s", new_acc)
  catf("Original MMCE: %s", old_acc)
  catf("Difference in MMCE: %s", round(old_acc - new_acc, 6))
  return(old_acc - new_acc)
}

library(doParallel)
registerDoParallel(10)

# out = c()
out = c(out, foreach(run.id = sample(runs$run.id, 30)) %do% reproduceFromRun(run.id))
res = abs(unlist(Filter(out, f = Negate(is.na))))
hist(res, breaks = 30)

# Reproduce recent runs from RandomBotNG
# ----------------------------------------------------------------------------------------
library(dplyr)
library(tidyr)
library(OpenML)

df = readRDS("~/Downloads/allruninfodf.rds")
tsks = read.csv("input/tasks.csv")
source("load_all.R", chdir = TRUE)
sapply(list.files("input/learners", full.names = TRUE), source)
system("testenv/export_muc_home.sh")
source("input/constants.R")
source("input/custom_learners.R")

rbn.getUnwatchedLearner = function(learner) {
  assertString(learner)
  lrn <- rbn.getCustomLearnerConstructor(learner) %??%
    function() makeLearner(learner)
  lrn <- suppressWarnings(setPredictType(lrn(), "prob"))
  wrapper <- rbn.getCustomLearnerConstructor("MODIFIER")
  if (!is.null(wrapper)) {
    lrn <- wrapper(lrn)
  }
  lrn
}

eval_point = function(point) {
  # Hacky way to make the strings available for eval(parse())
  cosine = "cosine"
  l2 = "l2"
  ip = "ip"
  impute.hist = "impute.hist"
  impute.median = "impute.median"
  impute.mean = "impute.mean"
  radial = "radial"
  linear = "linear"
  polynomial = "polynomial"
  ignore = "ignore"
  gini = "gini"
  partition = "partition"
  extratrees = "extratrees"
  order = "order"
  dart = "dart"
  gblinear = "gblinear"
  gbtree = "gbtree"
  eval(parse(text = point))
}

do_random_eval = function(task.id = NULL, learner = NULL) {
  if (!is.null(task.id)) assert_true(task.id %in% tsks$task.id_cv10)
  if (!is.null(learner)) assert_true(learner %in% df$learner)

  rw = df %>%
    filter(seed > 2000) %>%
    filter(totaltime < 20 & totaltime > 2) %>%
    sample_n(300) %>%
    separate(dataset, c("data.name", "data.id"), "\\.(?=[^\\.][:digit:]*$)") %>%
    mutate(data.id = as.integer(as.character(data.id))) %>%
    full_join(tsks)

  if (!is.null(task.id)) {
    rw = rw %>% filter(task.id_cv10 == task.id)
  }
  if (!is.null(learner)) {
    rw = rw %>% filter(learner == learner)
  } else {
    rw = rw %>%
      group_by(learner) %>%
      sample_n(1) %>%
      ungroup()
  }
  rw = rw %>% sample_n(1)

  lrn = rbn.getUnwatchedLearner(as.character(rw$learner))
  pv = eval_point(rw$point)

  # Quick and dirty check for valid param vals
  valid_pv = ifelse(is.null(pv$ef), TRUE, pv$ef > 2)
  valid_pv = ifelse(is.null(pv$ef), TRUE, pv$ef_construction > 2)
  valid_pv = (valid_pv & !pv$SUPEREVAL)
  pv$SUPEREVAL = NULL

  if (valid_pv) {
    lrn = setHyperPars(lrn, par.vals = pv)
    set.seed(rw$seed)
    tsk = convertOMLTaskToMlr(getOMLTask(rw$task.id_cv10, verbosity = 1))
    res = resample(lrn, tsk$mlr.task, tsk$mlr.rin)
    out = rw$perf.mmce - res$aggr
    catf("Task: %s, Learner %s", rw$task.id_cv10, rw$learner)
    catf("Params: %s", paste(names(pv), unlist(pv), sep = ":", collapse = ","))
    catf("Seed: %s, Invocation: %s", rw$seed, rw$invocation)
    catf("Reproduced MMCE: %s", res$aggr)
    catf("Original MMCE: %s", rw$perf.mmce)
    catf("Difference in MMCE: %s", round(out, 6))
  } else {
    out = NA
  }
  return(out)
}

library(doParallel)
registerDoParallel(10)
# out = c()
out = c(out, foreach(i = seq_len(10)) %do% do_random_eval(learner = "classif.xgboost.gbtree"))
