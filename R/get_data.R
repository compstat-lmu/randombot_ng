

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

    super.rdesc <- makeResampleDesc("RepCV",
      reps = rbn.getSetting("SUPERCV_REPS"),
      folds = 10,
      stratify = strat.tag)

    set.seed(1)
    super.resampling <- makeResampleInstance(super.rdesc, task = task$mlr.task)

    list(
        task = task$mlr.task,
        resampling = resampling,
        super.resampling = super.resampling)


  }
}

# reduce 'training' indices to the length they would have
# if cvinst were cross validation on the fraction-sized task.
# training sets of rbn.reduceCrossval with small fraction
# are subsets of rbn.reduceCrossval with larger fraction
# when the given task and cvinst is the same.
# @param cvinst [CVDesc]
# @param task [Task]
# @param fraction [numeric(1)]
# @return [ResampleDesc]
rbn.reduceCrossval <- function(cvinst, task, fraction) {
  assertClass(cvinst, "ResampleInstance")
  assertClass(cvinst$desc, "CVDesc")
  assertTRUE(cvinst$desc$iters == length(cvinst$train.inds))
  assertTRUE(cvinst$desc$iters == length(cvinst$test.inds))

  set.seed(2)

  targetcol <- getTaskTargets(task)

  new.size <- round(getTaskSize(task) * fraction)
  new.size.iters <- viapply(split(seq_len(new.size),
    rep_len(seq_len(cvinst$desc$iters),
      new.size)), length)

  if (cvinst$desc$stratify) {

    classfractions <- table(targetcol) / length(targetcol)

    cum.itertable <- classfractions * 0
    drop.per.iter <- lapply(seq_len(cvinst$desc$iters), function(iter) {
      # build "itertable"
      needed <- sum(new.size.iters[seq_len(iter)])
      itertable.dbl <- classfractions * needed
      itertable <- pmax(cum.itertable + 1, floor(itertable.dbl))
      missing <- needed - sum(itertable)
      assertTRUE(missing >= 0 && missing <= length(itertable))
      rest <- itertable.dbl - itertable
      to.inc <- order(rest, decreasing = TRUE)[seq_len(missing)]
      itertable[to.inc] <- itertable[to.inc] + 1
      assertTRUE(sum(itertable) == needed)
      itertable <- itertable - cum.itertable
      cum.itertable <<- cum.itertable + itertable
      # "itertable" is now a 'table' that gives the desired number of instances for each class

      foldindices <- cvinst$test.inds[[iter]]
      foldindices.split <- split(foldindices, targetcol[foldindices])

      present.itertable <- sapply(foldindices.split, length)

      assertTRUE(all(names(present.itertable) == names(itertable)))

      drop.per.class <- lapply(names(itertable), function(class) {
        todrop <- max(present.itertable[class] - itertable[class], 0)

        curfi <- foldindices.split[[class]]
        droppropose <- order(runif(length(curfi)))  # want to treat the seed the same independent of 'fraction' value

        curfi[droppropose[seq_len(todrop)]]
      })
      unlist(drop.per.class)
    })

  } else {

    drop.per.iter <- lapply(seq_len(cvinst$desc$iters), function(iter) {
      needed <- new.size.iters[iter]
      curfi <- cvinst$test.inds[[iter]]
      todrop <- length(curfi) - needed
      assertTRUE(todrop >= 0)

      droppropose <- order(runif(length(curfi)))

      curfi[droppropose[seq_len(todrop)]]
    })

  }

  drop.all <- unlist(drop.per.iter)
  for (iter in seq_len(cvinst$desc$iters)) {
    dropping <- intersect(cvinst$train.inds[[iter]], drop.all)
    cvinst$train.inds[[iter]] <- setdiff(cvinst$train.inds[[iter]], drop.all)
    cvinst$test.inds[[iter]] <- c(cvinst$test.inds[[iter]], dropping)
    assertTRUE(!anyDuplicated(cvinst$test.inds[[iter]]))
  }
  cvinst
}
