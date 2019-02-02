
# This script is supposed to give an idea how things should be run.

scriptdir <- Sys.getenv("MUC_R_HOME")
inputdir <- file.path(scriptdir, "input")

# load scripts & functions
source(file.path(scriptdir, "load_all.R"), chdir = TRUE)

# load custom learners & learner modifier
source(file.path(inputdir, "custom_learners.R"), chdir = TRUE)


# --------- during development: check the table
table <- rbn.compileParamTbl(file.path(inputdir, "spaces.csv"), sep = "\t")
rbn.checkParamTbl(table)


# --------- the following should always be at the head of an SRUN script
# --------- independent of scheduling mode

# the values are probably all to be configured from cmdline
rbn.registerSetting("BASEDIR", getwd())  # this would be the run / output dir
rbn.registerSetting("NODE_ID", 0)  # ranges from 0 to X, for node-local directory
rbn.registerSetting("LEARNER", get_learner_name_from_cmdline())
prbn.registerSetting("DATASET", get_task_name_from_cmdline())

####################################################################################
# --------- watchdog mode: all of this on a compute node --------------------------#
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

####################################################################################
# --------- "single" mode: each eval in its own srun ------------------------------#
####################################################################################

#################################################################################
# OPTION 1: if we send parameter strings to the srun, we have to prepare at home
# --------- the following on some random pc ---
rbn.registerSetting("SUPERRATE", 0.03)  # 3% extra eval rate
rbn.registerSetting("SAMPLING_TRAFO", "default+norm")  # normal distribution + trafo


table <- rbn.compileParamTbl(file.path(inputdir, "spaces.csv"), sep = "\t")

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

# --------- the following on the compute node --
rbn.registerSetting("SCHEDULING_MODE", "single")

learner.name = rbn.getSetting("LEARNER")
learner.object = rbn.getearner(learner.name)
data = rbn.getData(rbn.getSetting("DATASET"))  # function still needs to be defined

single.point.string <- get_point_string_from_cmdline()
point.value = rbn.parseEvalPoint(single.point.string)  # function to be defined
rbn.evaluatePoint(learner.object, point.value, data)  # obvious TODO here

#################################################################################
# OPTION 2: if we send only RUN_IDs (and learner / data names) to the SRUN calls
# --------- all of this on a compute node:

rbn.registerSetting("SCHEDULING_MODE", "single")

rbn.registerSetting("SUPERRATE", 0.03)  # 3% extra eval rate
rbn.registerSetting("SAMPLING_TRAFO", "default+norm")  # normal distribution + trafo

rbn.registerSetting("RUN_ID", get_run_id_from_cmdline())

learner.name = rbn.getSetting("LEARNER")
learner.object = rbn.getearner(learner.name)
data = rbn.getData(rbn.getSetting("DATASET"))  # function still needs to be defined

table <- rbn.compileParamTbl(file.path(inputdir, "spaces.csv"), sep = "\t")

runid <- rbn.getSetting("INIT_ID")
point.strings <- rbn.sampleEvalPoint(
    learner.name = learner.name,
    learner.object = learner.object,
    data = data,
    seet = runid,
    paramtbl = table)
# this can be multiple, for supererogatory evaluation
for (single.point.string in point.strings) {
  point.value = rbn.parseEvalPoint(single.point.string)  # function to be defined
  rbn.evaluatePoint(learner.object, point.value, data)  # obvious TODO here
}


