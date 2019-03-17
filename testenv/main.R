
# This script is supposed to give an idea how things should be run.

rm(list=ls(all.names = TRUE))  ; Sys.setenv(MUC_R_HOME = ".")

scriptdir <- Sys.getenv("MUC_R_HOME")
inputdir <- file.path(scriptdir, "input")

# load scripts & functions
source(file.path(scriptdir, "load_all.R"), chdir = TRUE)

# load custom learners & learner modifier
source(file.path(inputdir, "custom_learners.R"), chdir = TRUE)

# load constants
source(file.path(inputdir, "constants.R"), chdir = TRUE)

# --------- during development: check learner table, fill data directory
rbn.setupDataDir()

table <- rbn.compileParamTblConfigured()

# --------- PURELY TESTING: data

rbn.registerSetting("WATCHFILE", "/tmp/watchfile.txt")

datatable <- rbn.loadDataTable(file.path(inputdir, "tasks_test.csv"))

rbn.retrieveData(datatable)

data <- rbn.getData(datatable$name[2])

rbn.registerSetting("SAMPLING_TRAFO", "norm")

lrn <- rbn.getLearner("classif.ranger")

eps <- rbn.sampleEvalPoint(lrn, data$task, 3, table)
point <- rbn.parseEvalPoint(eps, lrn)

evalres <- rbn.evaluatePoint(lrn, eps, data)

evalres

epssuper <- gsub("SUPEREVAL=FALSE", "SUPEREVAL=TRUE", eps, fixed = TRUE)

evalressuper <- rbn.evaluatePoint(lrn, epssuper, data)

cvparts <- rbn.splitResamplingResult(evalressuper)

plot(sapply(cvparts, function(cvx) performance(cvx$pred, list(mmce))))





# --------- PURELY TESTING: parameters

lrn <- rbn.getLearner("classif.xgboost")

rbn.registerSetting("SAMPLING_TRAFO", "default")

rbn.registerSetting("SAMPLING_TRAFO", "none")

rbn.registerSetting("SAMPLING_TRAFO", "norm")

cat(rbn.sampleEvalPoint(lrn, iris.task, 9, table), "\n")
cat(rbn.sampleEvalPoint(lrn, iris.task, 10, table), "\n")
cat(rbn.sampleEvalPoint(lrn, iris.task, 11, table), "\n")
cat(rbn.sampleEvalPoint(lrn, iris.task, 12, table), "\n")
cat(rbn.sampleEvalPoint(lrn, iris.task, 13, table), "\n")
cat(rbn.sampleEvalPoint(lrn, iris.task, 14, table), "\n")
cat(rbn.sampleEvalPoint(lrn, iris.task, 15, table), "\n")
cat(rbn.sampleEvalPoint(lrn, iris.task, 531, table), "\n")



lrn <- rbn.getLearner("classif.ranger")

cat(rbn.sampleEvalPoint(lrn, iris.task, 1, table), "\n")

cat(collapse(vcapply(1:1000, function(i) rbn.sampleEvalPoint(lrn, iris.task, i, table)), ""))


cat(rbn.sampleEvalPoint(lrn, iris.task, 2, table), "\n")
cat(rbn.sampleEvalPoint(lrn, iris.task, 531, table), "\n")

vx <- rbn.sampleEvalPoint(lrn, iris.task, 9, table)
rbn.parseEvalPoint(vx, lrn)
xx <- rbn.parseEvalPoint(vx, lrn, multiple = FALSE)


sampleParam <- function(learner, len, param.name, trafo) {
  rbn.registerSetting("SAMPLING_TRAFO", trafo)

  lrn <- rbn.getLearner(learner)

  sapply(seq_len(len), function(i) {
    point <- rbn.sampleEvalPoint("classif.xgboost", lrn, iris.task, i, table)
    point <- rbn.parseEvalPoint(point, lrn)[[1]][[param.name]]
    if (is.null(point)) NA else point
  })
}

eta.default <- sampleParam("classif.xgboost", 10000, "eta", "default")
eta.none <- sampleParam("classif.xgboost", 10000, "eta", "none")
eta.norm <- sampleParam("classif.xgboost", 10000, "eta", "norm")

hist(log(eta.default))
hist(log(eta.norm))
hist(eta.none)




# --------- END PURELY TESTING

# --------- the following should always be at the head of an SRUN script
# --------- independent of scheduling mode

# the values are probably all to be configured from cmdline

####################################################################################
# --------- watchdog mode: all of this on a compute node ------------------------- #
####################################################################################

rbn.registerSetting("SCHEDULING_MODE", "watchdog")

rbn.registerSetting("STEPSIZE", 100)
rbn.registerSetting("SUPERRATE", 0.03)  # 3% extra eval rate
rbn.registerSetting("SAMPLING_TRAFO", "default+norm")  # normal distribution + trafo
# would want to do something smart here, like ask what INIT_ID was previously
# tried and failed if the process got killed before
rbn.registerSetting("INIT_ID", get_current_runid_from_file())  # TODO


runid <- rbn.getSetting("INIT_ID")
learner.name = rbn.getSetting("LEARNER")
learner.object = rbn.getearner(learner.name)
data = rbn.getData(rbn.getSetting("DATASET"))  # function still needs to be defined

table <- rbn.compileParamTbl(file.path(inputdir, "spaces.csv"), sep = "\t")

repeat {
  rbn.registerSetting("RUN_ID", runid, overwrite = TRUE)

  write_current_runid_to_file()  # TODO

  runid <- runid + rbn.getSetting("STEPSIZE")

  point.strings <- rbn.sampleEvalPoint(
      learner.name = learner.name,
      learner.object = learner.object,
      data = data,
      seet = runid,
      paramtbl = table)

  for (single.point.string in point.strings) {
    point.value = rbn.parseEvalPoint(single.point.string)  # function to be defined
    rbn.evaluatePoint(learner.object, point.value, data)  # obvious TODO here
  }
}

# maybe parallelize this; also will probably create huge files
for (learner in unique(table$learner)) {
  rbn.registerSetting("LEARNER", learner)

  learner.object = rbn.getearner(learner.name)
  for (task in get_all_tasks()) {
    rbn.registerSetting("DATASET", task)

    data = rbn.getData(rbn.getSetting("DATASET"))

    for (runid in seq_len(MAX_RUN_ID)) {
      point.strings <- rbn.sampleEvalPoint(
          learner.name = learner.name,
          learner.object = learner.object,
          data = data,
          seet = runid,
          paramtbl = table)
      for (single.point.string in point.strings) {
        write_to_srun_input_table(point.strings, learner, task)
      }
    }
  }
}

