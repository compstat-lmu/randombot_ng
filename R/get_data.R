
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

  library("OpenML")

  assert(
      checkDataFrame(table),
      checkString(table)
  )

  if (testString(table)) {
    table <- rbn.loadDataTable(table, ...)
  }

  taskcols <- grep("^task\\.id", colnames(table), value = TRUE)

  parallel::mclapply(sample(seq_len(nrow(table))), function(line) {

    catf("Retrieving task %s...", table$name[line])

    tasks <- sapply(taskcols, function(taskname) {
      omltask <- OpenML::getOMLTask(table[[taskname]][line], cache.only = TRUE, verbosity = 0)
      assert(all.equal(table[[taskname]][line], omltask$task.id))
      assert(all.equal(table$data.id[line], omltask$input$data.set$desc$id))
      omltask$input$evaluation.measures <- "root_mean_squared_error"

      strat.tag <- omltask$input$estimation.procedure$parameters$stratified_sampling
      if (is.null(strat.tag)) {
        warningf("Task %s %s has no 'stratified_sampling' info", taskname, table$name[line])
      }
      strat.tag <- isTRUE(all.equal(strat.tag, "true")) || is.null(strat.tag)
      if (!strat.tag) {
        messagef("Task %s %s does not do stratified resampling", taskname, table$name[line])
      }

      list(
        task = convertOMLTaskToMlr(omltask, mlr.task.id = table$name[line], verbosity = 0),
        strat.tag = strat.tag
      )
    }, simplify = FALSE)

    for (t in tasks) {
      assertTRUE(all.equal(tasks[[1]]$task$mlr.task, t$task$mlr.task))  # only resampling should differ
    }

    resampling <- lapply(tasks, function(t) {
      res <- t$task$mlr.rin
      res$desc$stratify <- t$strat.tag
      res
    })

    set.seed(1)
    super.resampling <- rbn.unionResample(c(
        resampling[-1],
        lapply(sort(rbn.getSetting("SUPERCV_PROPORTIONS"), decreasing = TRUE),
          rbn.reduceCrossval, task = tasks[[1]]$task$mlr.task, cvinst = resampling[[1]])
    ))

    data <- list(
      task = tasks[[1]]$task$mlr.task,
      resampling = resampling[[1]],
      super.resampling = super.resampling
    )

    saveRDS(data, file = file.path(rbn.getSetting("DATADIR"), paste0(table$name[line], ".rds.gz")),
      version = 2, compress = "gzip")
    catf("Done with %s.", table$name[line])
  }, mc.cores = round(parallel::detectCores() / 1.5), mc.preschedule = FALSE)
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
  intable <- read.csv(file, stringsAsFactors = FALSE, ...)
  assertDataFrame(intable)

  # check that all required names are present
  assertTRUE(all(sapply(required.names, function(rn) any(grepl(paste0("^", rn, "$"), colnames(intable))))))
  assertIntegerish(intable$data.id)
  table <- data.frame(
      name = as.character(intable$name),
      data.id = as.integer(intable$data.id))

  table <- cbind(table, as.data.frame(sapply(grep(paste0("^task\\.id"), colnames(intable), value = TRUE),
    function(colname) {
      assertIntegerish(intable[[colname]])
      as.integer(intable[[colname]])
    })))

  # TODO: convert task.id columns to integer


  table$name <- paste(make.names(table$name), table$data.id, sep = ".")
  assertCharacter(table$name, unique = TRUE)
  assertInteger(table$data.id, unique = TRUE)

  table
}
