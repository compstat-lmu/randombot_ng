

rbn.writeResult <- function(result, task, learner, arg) {
  rbn.setOutputDir()

  file <- file.path(rbn.getSetting("OUTPUTDIR"), sprintf("RESULT_%s_%s_%s.rds.gz", task, learner, arg))

  saveRDS(result, file = file, version = 2, compress = "gzip")
}

