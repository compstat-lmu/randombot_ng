

# Download the dataset and task from OpenML and save to DATADIR
# @param table [character(1) | data.frame] task information table
#   Either a data.frame or a file to be loaded with `read.csv`
# @param ... additional arguments to read.csv if `table` is a [character(1)].
rbn.retrieveData <- function(table, ...) {
  required.names <- c("name", "task.id", "data.id")

  assert(
      checkDataFrame(table),
      checkString(table)
  )

  if (testString(table)) {
    table <- read.csv(table, ...)
    assertDataFrame(table)
  }
  assertNames(colnames(table), must.include = required.names)

  table <- data.frame(
      name = as.character(table$name),
      task.id = as.integer(table$task.id),
      data.id = as.integer(table$data.id))

  table$name <- paste(make.names(table$name), table$task.id, sep = ".")
  assertCharacter(table$name, unique = TRUE)
  assertInteger(table$data.id, unique = TRUE)

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
    super.resampling <- replicate(rbn.getSetting("SUPERCV_REPS"),
      makeResampleInstance(super.rdesc, task = task$mlr.task))

    super.resampling <- c(super.resampling,
      lapply(rbn.getSetting("SUPERCV_PROPORTIONS", function(frac) {
        rbn.reduceCrossval(resampling, task, frac)
      })))

    super.resampling <- rbn.unionResample(super.resampling)

    data <- list(
      task = task$mlr.task,
      resampling = resampling,
      super.resampling = super.resampling
    )

    saveRDS(data, file = file.path(rbn.getSetting("DATADIR"), paste0(table$name[line], ".rds.gz")),
      version = 2, compress = "gzip")
  }
}

