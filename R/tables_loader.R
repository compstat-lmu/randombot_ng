
# load SEARCHSPACE table from configured location
rbn.compileParamTblConfigured <- function() {
  path <- rbn.getSetting("SEARCHSPACE_TABLE")
  options <- eval(parse(text = rbn.getSetting("SEARCHSPACE_TABLE_OPTS")))
  assertList(options)
  do.call(rbn.compileParamTbl, c(list(path), options))
}

rbn.loadDataTableConfigured <- function() {
  path <- rbn.getSetting("DATA_TABLE")
  options <- eval(parse(text = rbn.getSetting("DATA_TABLE_OPTS")))
  assertList(options)
  do.call(rbn.loadDataTable, c(list(path), options))
}
