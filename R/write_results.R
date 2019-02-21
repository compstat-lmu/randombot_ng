

rbn.writeResult <- function(result, name) {
  rbn.setOutputDir()

  file <- file.path(rbn.getSetting("OUTPUTDIR"), sprintf("RESULT_%s.rds.gz", tag))

  saveRDS(result, file = file, version = 2, compress = "gzip")
}

