
# Prepare inputs
# - load data and learner tables as configured in constants.R
# - check learner table
# - retrieve data
# - write LEARNERS and TASKS file into DATADIR
# Expects custom learners to already have been loaded
rbn.setupDataDir <- function() {
  table <- rbn.compileParamTblConfigured()
  rbn.checkParamTbl(table)

  datatable <- rbn.loadDataTableConfigured()
  rbn.retrieveData(datatable)

  fname <- file.path(rbn.getSetting("DATADIR"), "LEARNERS")
  cat(table$learner, sep = "\n", file = fname)

  fname <- file.path(rbn.getSetting("DATADIR"), "TASKS")
  cat(datatable$name, sep = "\n", file = fname)
}

# Download the dataset and task from OpenML and save to DATADIR
# @param table [character(1) | data.frame] task information table
#   Either a data.frame or a file to be loaded with `read.csv`
# @param ... additional arguments to read.csv if `table` is a [character(1)].
rbn.retrieveData <- function(table, ...) {

  assert(
      checkDataFrame(table),
      checkString(table)
  )

  if (testString(table)) {
    table <- rbn.loadDataTable(table, ...)
  }

  for (line in seq_len(nrow(table))) {

    omltask <- OpenML::getOMLTask(table$task.id[line])
    assert(all.equal(table$task.id[line], omltask$task.id))
    assert(all.equal(table$data.id[line], omltask$input$data.set$desc$id))
    omltask$input$evaluation.measures <- "root_mean_squared_error"

    task <- convertOMLTaskToMlr(omltask, mlr.task.id = table$name[line])

    strat.tag <- omltask$input$estimation.procedure$parameters$stratified_sampling
    if (is.null(strat.tag)) {
      warningf("Task %s has no 'stratified_sampling' info", table$name[line])
    }
    strat.tag <- isTRUE(all.equal(strat.tag, "true")) || is.null(strat.tag)
    if (!strat.tag) {
      messagef("Task %s does not do stratified resampling", table$name[line])
    }

    resampling <- task$mlr.rin
    resampling$desc$stratify <- strat.tag

    super.rdesc <- makeResampleDesc("CV",
      iters = 10,
      stratify = strat.tag)

    set.seed(1)
    super.resampling <- rbn.unionResample(c(
        replicate(rbn.getSetting("SUPERCV_REPS"),
          makeResampleInstance(super.rdesc, task = task$mlr.task), simplify = FALSE),
        lapply(sort(rbn.getSetting("SUPERCV_PROPORTIONS"), decreasing = TRUE),
          rbn.reduceCrossval, task = task$mlr.task, cvinst = resampling)
    ))

    data <- list(
      task = task$mlr.task,
      resampling = resampling,
      super.resampling = super.resampling
    )

    saveRDS(data, file = file.path(rbn.getSetting("DATADIR"), paste0(table$name[line], ".rds.gz")),
      version = 2, compress = "gzip")
  }
}

# Read dataset that was saved in DATADIR
# @param dataname the canonical name, as in `rbn.loadDataTable()`
rbn.getData <- function(dataname) {
  readRDS(file.path(rbn.getSetting("DATADIR"), paste0(dataname, ".rds.gz")))
}

# Load the dataset info table
# @param file [data.frame] task information table file path
# @param ... additional arguments to read.csv
rbn.loadDataTable <- function(file, ...) {
  required.names <- c("name", "task\\.id.*", "data\\.id")

  assertString(file)
  intable <- read.csv(file, ...)
  assertDataFrame(intable)

  # check that all required names are present
  assertTRUE(all(sapply(required.names, function(rn) any(grepl(paste0("^", rn, "$"), colnames(intable))))))

  table <- data.frame(
      name = as.character(intable$name),
      data.id = as.integer(intable$data.id))

  # TODO: convert task.id columns to integer


  table$name <- paste(make.names(table$name), table$task.id, sep = ".")
  assertCharacter(table$name, unique = TRUE)
  assertInteger(table$data.id, unique = TRUE)

  table
}
