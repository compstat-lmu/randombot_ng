# Reproduce stuff from old randombot

library(OpenML)
library(BBmisc)
runs = listOMLRuns(tag="mlrRandomBot", limit = 5000, offset = 20000, flow.id = 6767)

reproduceFromRun = function(run.id) {
  r = getOMLRun(run.id)
  flow = getOMLFlow(r$flow.id)
  task = getOMLTask(r$task.id)
  if (flow$name == "mlr.classif.xgboost") {
    #Convert factors to numeric
    target = task$input$data.set$target.features
    cols = which(colnames(task$input$data.set$data) != target)
    task$input$data.set$data = data.frame(
      sapply(dummies::dummy.data.frame(task$input$data.set$data[,cols], sep = "_._"), as.numeric),
      task$input$data.set$data[,target,drop = FALSE])
    colnames(task$input$data.set$data) = make.names(colnames(task$input$data.set$data))
  }
  pars = getOMLRunParList(r)

  out = runTaskFlow(
    task = task,
    par.list = pars,
    flow =  flow,
    seed = 1L)
  old_acc = r$output.data$evaluations[r$output.data$evaluations$name == "predictive_accuracy", "value"][1]
  new_acc = out$bmr$results[[1]][[1]]$aggr["acc.test.join"]
  catf("Task: %s, Learner %s", r$task.id, r$flow.id)
  # catf("Params: %s", paste(data.frame(pars)$name, data.frame(pars)$value, sep = ":", collapse = ","))
  catf("Reproduced MMCE: %s", new_acc)
  catf("Original MMCE: %s", old_acc)
  catf("Difference in MMCE: %s", round(old_acc - new_acc, 6))
  delta = old_acc - new_acc
  names(delta) = run.id
  return(delta)
}


library(OpenML)
library(dplyr)
run.id = 3802515
r = getOMLRun(run.id)
r$output.data$evaluations %>% filter(name == "predictive_accuracy") %>% select("value", "fold")
r$predictions %>% group_by(fold) %>% summarize(acc = mlr::measureACC(truth, prediction))


library(doParallel)
registerDoParallel(10)

out = c()
run.ids = sample(runs$run.id, 1)
out = c(out, (foreach(run.id = run.ids) %do% reproduceFromRun(run.id)))
res = abs(unlist(Filter(out, f = Negate(is.na))))
hist(res, breaks = 30)

# Reproduce recent runs from RandomBot
# ----------------------------------------------------------------------------------------
#' @title evalConfigurations
#' This evaluates all configurations of a single learner and a matching task.
#' Configurations in par should be valid for task.
#' @param lrn Learner
#' @param task OMLTask
#' @param par data.frame of configurations to evaluate
#' @param min.resources minimal used resources
#' @param max.resources maximum allowed resources for a single evaluation
#' @param upload should the run be uploaded
#'
#' @export
evalConfigurations = function(lrn, task, par, min.resources, max.resources, upload, path) {

  if(!dir.exists(path)){
    reg = makeExperimentRegistry(file.dir = path,
      packages = c("mlr", "OpenML", "BBmisc"),
      namespaces = "rscimark")
      #conf.file = ".batchtools.conf.R")
  } else {
    reg = loadRegistry(file.dir = path)
  }

  addProblem(name = task$name, data = task$task)

  addAlgorithm(lrn$short.name, fun = function(job, data, instance, mlr.lrn = lrn,
    should.upload = upload, add.tags = attr(par, "additional.tags"), ...) {

    # Run mlr
    mlr.par.set = list(...)
    mlr.par.set = mlr.par.set[!vlapply(mlr.par.set, is.na)]
    mlr.lrn = setHyperPars(mlr.lrn, par.vals = mlr.par.set)
    sci.bench = rscimark::rscimark() #FIXME: only execute this once. source in makeExperiment doesn't work...
    res = runTaskMlr(data, mlr.lrn, scimark.vector = sci.bench)
    print(res)
    if (should.upload) {
      tags = c("mlrRandomBot", add.tags)
      uploadOMLRun(res, confirm.upload = FALSE, tags = tags, verbosity = 1)
    }

    return(TRUE)
  })

  design = list(par)
  names(design) = lrn$short.name
  addExperiments(algo.designs = design, reg = reg)

  if (!is.null(max.resources)){
    reg$cluster.functions = makeClusterFunctionsSlurm("slurm_lmulrz.tmpl", clusters = "serial")
    # exponentialBackOff(jobs = 1:nrow(par), registry = reg, start.resources = min.resources, max.resources = max.resources)
    submitJobs(resources = max.resources)
    waitForJobs()
  } else {
    reg$cluster.functions = makeClusterFunctionsSocket(2)
    submitJobs()
  }
  waitForJobs(reg = reg)
  unlink(path, recursive = TRUE)
}

reproduceFromRun2 = function(run.id, seed = 1L) {
  r = getOMLRun(run.id)
  flow = getOMLFlow(r$flow.id)
  task = getOMLTask(r$task.id)
  pars = getOMLRunParList(r)

  lrn = convertOMLFlowToMlr(flow)
  lrn = mlr::setHyperPars(lrn, par.vals = getDefaults(getParamSet(lrn)))
  par.vals = OpenML:::convertOMLRunParListToList(pars, ps = getParamSet(lrn))
  lrn.pars = par.vals[names(par.vals) %nin% c("seed", "kind", "normal.kind")]

  # From RunTaskFlow
  lrn = do.call("setHyperPars", append(list(learner = lrn), list(par.vals = lrn.pars)))
  # From RandomBot
  mlr.lrn = setHyperPars(lrn, par.vals = lrn.pars)

  mlr.task = convertOMLTaskToMlr(task)
  set.seed(seed)
  bmr = benchmark(lrn, mlr.task$mlr.task, mlr.task$mlr.rin, measures = acc)
  # set.seed(seed)
  # bmr = benchmark(lrn, mlr.task$mlr.task, mlr.task$mlr.rin, measures = acc)

  old_acc = r$output.data$evaluations[r$output.data$evaluations$name == "predictive_accuracy" & is.na(r$output.data$evaluations$fold), "value"]
  new_acc = getBMRAggrPerformances(bmr)[[1]][[1]]
  catf("Task: %s, Learner %s", r$task.id, r$flow.id)
  catf("Params: %s", paste(data.frame(pars)$name, data.frame(pars)$value, sep = ":", collapse = ","))
  catf("Reproduced MMCE: %s", new_acc)
  catf("Original MMCE: %s", old_acc)
  catf("Difference in MMCE: %s", round(old_acc - new_acc, 6))
  return(old_acc - new_acc)
}



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
    set.seed(2)
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
