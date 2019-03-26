

rbn.writeResult <- function(result, task, learner, arg) {
  rbn.setOutputDir()

  file <- file.path(rbn.getSetting("OUTPUTDIR"), sprintf("RESULT_%s_%s_%s.rds.gz", task, learner, substr(digest::digest(arg), 1, 16)))

  catf("Writing to %s", file)

  saveRDS(result, file = file, version = 2, compress = "gzip")
  catf("Done Writing")
}

