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

rbn.checkParamTbl(table)

# --------- PURELY TESTING: data

rbn.registerSetting("WATCHFILE", "/tmp/watchfile.txt")

datatable <- rbn.loadDataTable(file.path(inputdir, "tasks.csv"))

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

table <- rbn.loadDataTable(file.path(inputdir, "tasks.csv"))

str(read.csv(file.path(inputdir, "tasks.csv"), stringsAsFactors = FALSE)$task.id_10cv10)

getdata <- populateOMLCache(
  data.ids = table$data.id,
  task.ids = unique(unlist(table[grep("^task\\.id", colnames(table), value = TRUE)])))

setOMLConfig(cachedir = "/projects/user/supermuc_ng/cache")
saveOMLConfig()



alltaskinfo <- read.csv("/projects/user/supermuc_ng/alltaskinfo", sep = " ")
names(alltaskinfo)

repinfo <- read.csv("/projects/user/supermuc_ng/repinfo", sep = " ")

subset(repinfo, taskid %in% table$task.id_cv10 & reps != 1)
subset(repinfo, taskid %in% table$task.id_10cv10 & reps != 10)

reform <- aggregate(alltaskinfo$taskid, by = alltaskinfo["datasetid"], FUN = identity)

baddata <- setdiff(alltaskinfo$datasetid, table$data.id)

brokentaskid <- subset(alltaskinfo, datasetid %in% baddata)$taskid

halfmissingdataid <- table$data.id[apply(
  table[grep("^task\\.id", colnames(table), value = TRUE)], 1,
  function(x) any(brokentaskid %in% x))]

halfmissingdataid

reform <- subset(reform, datasetid %nin% baddata)

unacctdataid <- reform$datasetid[sapply(reform$x, length) == 1]

alltaskids <- unlist(table[grep("^task\\.id", colnames(table), value = TRUE)])
duplis <- alltaskids[duplicated(alltaskids)]
maybeduplidata <- table$data.id[apply(
  table[grep("^task\\.id", colnames(table), value = TRUE)], 1,
  function(x) any(x %in% duplis))]


unacctdataid

setdiff(unacctdataid, halfmissingdataid)
maybeduplidata

duplis

table$data.id[which(table$task.id_10cv10 %in% duplis)]
table$data.id[which(table$task.id_cv10 %in% duplis)]

table$data.id[which(table$task.id_10cv10 %in% brokentaskid)]
table$data.id[which(table$task.id_cv10 %in% brokentaskid)]

# write.csv(subset(table, data.id %nin% unacctdataid), "input/tasks_repaired.csv")



table[111, ]

ot <- OpenML::getOMLTask(table[["task.id_cv10"]][15], cache.only = TRUE, verbosity = 0)



ot2 <- OpenML::getOMLTask(table[["task.id_10cv10"]][111], cache.only = TRUE, verbosity = 0)
ot$input$evaluation.measure <- "root_mean_squared_error"
ot2$input$evaluation.measure <- "root_mean_squared_error"
ott <- convertOMLTaskToMlr(ot, mlr.task.id = table$name[111], verbosity = 0)
ott2 <- convertOMLTaskToMlr(ot2, mlr.task.id = table$name[111], verbosity = 0)

res <- ott$mlr.rin
res$desc$stratify <- TRUE

set.seed(1)
lapply(sort(rbn.getSetting("SUPERCV_PROPORTIONS"), decreasing = TRUE),
  rbn.reduceCrossval, cvinst = ott$mlr.rin, task = ott$mlr.task)



15, 31, 47, 63, 79, 95,
ll(15)
ll(31)
ll(47)
ll(63)
ll(79)
ll(95) # <-- ?!


table[95, ]


# ---------------------------------

cpx <- .custom.learner.register$MODIFIER(NULLCPO)
cpx <- setHyperPars(cpx, num.impute.selected.cpo = "impute.mean")

datasizes <- t(sapply(datatable$name, function(dname) {
  dataset <- rbn.getData(dname)$task %>>% cpx
  c(p = getTaskNFeats(dataset),
    p.dummy = getTaskNFeats(dataset %>>% cpoDummyEncode(reference.cat = TRUE, infixdot = TRUE)),
    n = getTaskSize(dataset))
}))

# write.csv(datasizes, file = "notes/datasizes.csv")

read.csv("notes/datasizes.csv")
