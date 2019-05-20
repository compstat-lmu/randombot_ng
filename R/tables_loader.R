
# load SEARCHSPACE table from configured location
rbn.compileParamTblConfigured <- function() {
  path <- rbn.getSetting("SEARCHSPACE_TABLE")
  options <- eval(parse(text = rbn.getSetting("SEARCHSPACE_TABLE_OPTS")))
  path.p <- rbn.getSetting("SEARCHSPACE_PROP_TABLE")
  options.p <- eval(parse(text = rbn.getSetting("SEARCHSPACE_PROP_TABLE_OPTS")))
  assertList(options)
  tbl1 <- do.call(rbn.compileParamTbl, c(list(path), options))
  tbl2 <- do.call(read.csv, c(list(path.p), options.p))
  tbl2 <- tbl2[c("learner", "proportion")]
  tbl2$proportion <- as.numeric(tbl2$proportion)
  merge(tbl1, tbl2, by = "learner", all.x = TRUE)
}

rbn.loadDataTableConfigured <- function() {
  path <- rbn.getSetting("DATA_TABLE")
  options <- eval(parse(text = rbn.getSetting("DATA_TABLE_OPTS")))
  path.p <- rbn.getSetting("DATA_PROP_TABLE")
  options.p <- eval(parse(text = rbn.getSetting("DATAP_PROP_TABLE_OPTS")))
  assertList(options)
  assertList(options.p)
  rbn.loadDataTable(path, options, path.p, options.p)
}

rbn.loadMemoryTableConfigured <- function() {
  path <- rbn.getSetting("MEMORY_TABLE")
  options <- eval(parse(text = rbn.getSetting("MEMORY_TABLE_OPTS")))
  assertList(options)
  tbl <- do.call(read.csv, c(list(path, stringsAsFactors = FALSE), options))
  assertDataFrame(tbl, col.names = c("dataset", "learner", "memory_limit"))
  tbl
}
