# This script is supposed to give an idea how things should be run.
# It can also serve as a stash of interactive commands that are useful.

# WARNING: the following clears the workspace!

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



