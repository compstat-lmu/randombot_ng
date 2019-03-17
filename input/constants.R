

rbn.setEnvToLoad(c("NODEDIR", "WORKDIR", "MUC_R_HOME", "WATCHFILE"))


PERCVTIME = 300
rbn.registerSetting("RESAMPLINGTIMEOUTS",
  c(0.8, 0.9, 0.9, 1.0, 1.0,
    1.0, 1.0, 1.1, 1.1, 1.2,
    1.5) * PERCVTIME)


rbn.registerSetting("SUPERRATE", 0.01)

rbn.registerSetting("SAMPLING_TRAFO", "norm")

rbn.registerSetting("SEARCHSPACE_TABLE", file.path(getwd(), "spaces.csv"))
rbn.registerSetting("SEARCHSPACE_TABLE_OPTS", 'list(sep = "\\t", quote = "")')

rbn.setOutputDir <- function() {
  dir <- rbn.registerSetting("OUTPUTDIR", overwrite = TRUE,
    file.path(rbn.getSetting("WORKDIR"), format(Sys.time(), "%F_%H")))
  dir.create(file.path(dir), showWarnings = FALSE)
  dir
}


# WARNING: ALL OF the following changes the data which is cached
# in the DATADIR folder. Be sure to call rbn.retrieveData() when this changes.
rbn.registerSetting("DATADIR",
  file.path(rbn.getSetting("MUC_R_HOME"), "data"))

rbn.registerSetting("DATA_TABLE", file.path(getwd(), "tasks_test.csv"))
rbn.registerSetting("DATA_TABLE_OPTS", 'list()')

rbn.registerSetting("SUPERCV_REPS", 30)
rbn.registerSetting("SUPERCV_PROPORTIONS",
  c(0.05, 0.1, 0.15, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9))

