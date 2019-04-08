# Reproduce stuff from old randombot
library(OpenML)
run.id = 2118729
# reproduceFromRun = function(run.id) {
  r = getOMLRun(run.id)
  flow = getOMLFlow(r$flow.id)
  task = getOMLTask(r$task.id)
  pars = getOMLRunParList(r)
  runTaskFlow(
    task = task,
    par.list = pars,
    flow =  flow)
# }

reproduceFromRun(2118729)

# Reproduce recent runs


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

do_random_eval = function(task.id = NULL) {
  if (is.null(task.id)) {
    task.id = sample(tsks$task.id_cv10, 1)
  }
  assert_true(task.id %in% tsks$task.id_cv10)
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

  rw = df %>%
    filter(seed > 3000) %>%
    separate(dataset, c("data.name", "data.id"), "\\.(?=[^\\.][:digit:]*$)") %>%
    mutate(data.id = as.integer(as.character(data.id))) %>%
    left_join(tsks) %>%
    filter(task.id_cv10 == as.integer(task.id)) %>%
    mutate(SUPEREVAL = eval(parse(text = point))$SUPEREVAL) %>%
    filter(!SUPEREVAL) %>%
    sample_n(1)

  catf("Task: %s, Learner %s", task.id, rw$learner)
  lrn = rbn.getUnwatchedLearner(as.character(rw$learner))
  pv = eval(parse(text = rw$point))
  pv$SUPEREVAL = NULL
  lrn = setHyperPars(lrn, par.vals = pv)

  set.seed(rw$seed)
  tsk = convertOMLTaskToMlr(getOMLTask(rw$task.id_cv10))
  res = resample(lrn, tsk$mlr.task, tsk$mlr.rin)
  out = rw$perf.mmce - res$aggr
  catf("Params: %s", paste(names(pv), unlist(pv), sep = ":", collapse = ","))
  catf("Reproduced MMCE: %s", res$aggr)
  catf("Original MMCE: %s", rw$perf.mmce)
  catf("Difference in MMCE: %s", round(out, 6))
  return(out)
}

do_random_eval()
