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


library(dplyr)
library(tidyr)
library(OpenML)
df = readRDS("~/Downloads/allruninfodf.rds")
source("load_all.R", chdir = TRUE)
sapply(list.files("input/learners", full.names = TRUE), source)
system("testenv/export_muc_home.sh")
source("input/constants.R")
source("input/custom_learners.R")
# REQ: Latest mlrCPO version


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

data.id = "469"
do_random_eval = function(data.id) {
  rw = df %>%
    separate(dataset, c("name", "data.id"), "\\.(?=[^\\.][:digit:]*$)") %>%
    filter(data.id == data.id) %>%
    sample_n(1)
  lrn = rbn.getUnwatchedLearner(as.character(rw$learner))
  pv = eval(parse(text = rw$point))
  pv$SUPEREVAL = NULL
  lrn = setHyperPars(lrn, par.vals = pv)
  set.seed(rw$seed)
  t = convertOMLTaskToMlr(getOMLTask(3560))
  res = resample(lrn, t$mlr.task, t$mlr.rin)
  out = rw$perf.mmce - res$aggr
  return(out)
}

do_random_eval("469")