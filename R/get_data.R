
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
  cat(unique(table$learner), sep = "\n", file = fname)

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
# @param datafile [data.frame] task information table file path
# @param dataoptions additional arguments to read.csv
# @param propfile [data.frame] task information table file path
# @param propoptions additional arguments to read.csv
rbn.loadDataTable <- function(datafile, dataoptions = list(), propfile, propoptions = list()) {
  required.names <- c("name", "task\\.id.*", "data\\.id")

  assertString(datafile)
  intable <- do.call(read.csv,
    c(list(datafile, stringsAsFactors = FALSE), dataoptions))
  assertDataFrame(intable)

  assertString(propfile)
  proptable <- do.call(read.csv,
    c(list(propfile, stringsAsFactors = FALSE), propoptions))
  assertDataFrame(proptable)

  # check that all required names are present
  assertTRUE(all(sapply(required.names, function(rn) any(grepl(paste0("^", rn, "$"), colnames(intable))))))
  assertIntegerish(intable$data.id)
  table <- data.frame(
      name = as.character(intable$name),
      data.id = as.integer(intable$data.id),
      stringsAsFactors = FALSE)

  table <- cbind(table, as.data.frame(sapply(grep(paste0("^task\\.id"), colnames(intable), value = TRUE),
    function(colname) {
      assertIntegerish(intable[[colname]])
      as.integer(intable[[colname]])
    })))

  # TODO: convert task.id columns to integer

  table$name <- paste(make.names(table$name), table$data.id, sep = ".")
  assertCharacter(table$name, unique = TRUE)
  assertInteger(table$data.id, unique = TRUE)

  assertSetEqual(table$name, proptable$dataset)

  assertNumeric(proptable$prob, any.missing = FALSE)

  table$proportion <- proptable$prob[match(table$name, proptable$dataset)]
  table$proportion <- table$proportion / sum(table$proportion)

  table
}

#' Use a data.id and learner to obtain ~max memory requirements
#' Defaults to 2GB.
#' @param data.id [integer(1)]
#' @param learner [character(1)]
#' @return [numeric(1)] number of MB required, rounded upwards.
#' @example
#' rbn.getMemoryRequirementsKb("riccardo.41161", "classif.svm")
#' DEPRECATED, use rbn.loadMemoryTableConfigured()
rbn.getMemoryRequirementsKb = function(task, learner) {
  # CSV created from /setup/003_predict_memory_requirements.R
  tab = read.table(
      file.path(Sys.getenv("MUC_R_HOME"),
        "input",
        "memory_requirements.csv"))
  kb = tab[tab$dataset == task & tab$learner == learner, "memory_limit"]
  # Fallback and make sure it is at least 300 MB
  if (length(kb) == 0) kb = 2048 * 1024
  if (is.na(kb) | is.null(kb) | is.nan(kb)) kb = 1024 * 1024
  kb = max(kb, 300 * 1024)
  ceiling(kb / 1024) + 50
}


#' Get Task Probabilities
#' Defaults to 1%
#' @param data.id [integer(1)]
#' @return [numeric(1)] probability to draw the dataset.
#' @example
#' rbn.getTaskProbabilities("riccardo.41161")
#' DEPRECATED, task probs are loaded in rbn.loadDataTableConfigured()
rbn.getTaskProbabilities = function(task) {
  # CSV created from /setup/003_predict_memory_requirements.R
  tab = read.table(
      file.path(Sys.getenv("MUC_R_HOME"),
        "input",
        "dataset_probs.csv"))
  prob = tab[tab$dataset == task, "prob"]
  if (length(prob) == 0) prob = 0.01
  if (is.na(prob) | is.null(prob) | is.nan(prob)) prob = 0.01
  return(max(prob, 0.001))
}


rbn.DistributeSrunsToNodes.GREEDY <- function(nodes) {
  # this function assigns "tasks" to "nodes", where a "task" is one of the
  # possible learner x data combinations.

  physcores <- assertInt(rbn.getSetting("PHYSCORES"), coerce = TRUE)

  # Assumption is made that intel SMT ("Hyper-Threading") is available such that
  # "physcores" can be over-subscribed, but that the additional thread only
  # gets HTbenefit as much performance.
  HTbenefit <- rbn.getSetting("HTBENEFIT")

  mempernode <- rbn.getSetting("MEMPERNODE")

  # get learners and their proportions
  table <- rbn.compileParamTblConfigured()
  proptable <- aggregate(table$proportion, by = table["learner"], FUN = mean)
  learners <- proptable$learner
  lrnproportions <- proptable$x
  names(lrnproportions) <- learners

  # get dataset names
  datatbl <- rbn.loadDataTableConfigured()
  dataproportions <- datatbl$proportion
  names(dataproportions) <- datatbl$name

  # tasks are {datasets} (x) {learners}
  fulltasks <- merge(
      expand.grid(dataset = datatbl$name, learner = learners,
        stringsAsFactors = FALSE),
      rbn.loadMemoryTableConfigured(),
      all.x = TRUE)[c("dataset", "learner", "memory_limit")]
  names(fulltasks) <- c("data", "learner", "memcosts")
  fulltasks$memcosts <- pmax(ceiling(fulltasks$memcosts / 1024) + 50, 350)
  fulltasks$memcosts[is.na(fulltasks$memcosts)] <- 2048

  # proportions: the proportions of dataset-learner pairs
  fulltasks$proportions <- lrnproportions[fulltasks$learner] * dataproportions[fulltasks$data]

  assignment <- rbn.assignTasks(fulltasks$proportions, fulltasks$memcosts,
    length(nodes), mempernode, physcores, HTbenefit)$assignment

  cbind(fulltasks[assignment$taskno, c("data", "learner", "memcosts")],
    node = nodes[assignment$node], stringsAsFactors = FALSE)
}

# assign tasks with desired proportions `props` and memory usage `memusage`
# to `nodes` work nodes that
# each have `mempernode` memory and `physcores` cores available. If `HTbenefit`
# is not `NULL` then SMT is available, but each additional thread only performs
# `HTbenefit` as much as a non-SMT thread.
rbn.assignTasks <- function(props, memusage, nodes, mempernode, physcores, HTbenefit = NULL) {

  props <- props / sum(props)

  maxcores <- physcores * (1 + !is.null(HTbenefit))

  # how many work units a task already has
  currentWU <- vector("numeric", length(props))

  # whether there is not a large enough memory block left to run another unit of the
  # task
  infeasible <- vector("logical", length(props))

  # how much memory is left on each node
  memfree <- rep(mempernode, nodes)

  # how many processes run on each node
  coresused <- rep(0, nodes)

  # matrix that lists which task is assigned to which node how many times
  assignmat <- as.data.frame(matrix(0, nrow = length(props), ncol = nodes))

  # slowdown due to SMT on over-subscribed cores
  scalingfactor <- rep(1, nodes)

  # collect results
  astaskno <- integer(maxcores * nodes)
  asnode <- integer(maxcores * nodes)
  iter <- 0

  while (!all(infeasible)) {

    # next task to assign
    curtask <- which(!infeasible)[
      which.min(currentWU[!infeasible] / props[!infeasible])]

    # memory cost of that task
    mc <- memusage[curtask]

    # Assign to the first node that has enough free memory
    nodesel <- c(which(mc <= memfree & coresused < maxcores), Inf)[1]

    if (is.infinite(nodesel)) {
      # task doesn't fit anywhere: mark task as infeasible
      infeasible[curtask] <- TRUE
      next
    }

    # assign task to node
    iter <- iter + 1
    astaskno[iter] <- curtask
    asnode[iter] <- nodesel

    # update data about used memory, cores etc.
    memfree[nodesel] <- memfree[nodesel] - mc
    coresused[nodesel] <- coresused[nodesel] + 1
    assignmat[[nodesel]][curtask] <- assignmat[[nodesel]][curtask] + 1

    # scale down productivity of nodes if they have more tasks than physical
    # cores
    if (coresused[nodesel] > physcores) {
      # we only get here if maxcores > physcores, so HTbenefit is not NULL.
      totalPerf <- physcores + (coresused[nodesel] - physcores) * HTbenefit

      before.scaling <- scalingfactor[nodesel]
      scalingfactor[nodesel] <- totalPerf / coresused[nodesel]
      # .. update the column of work units assigned for each task

      # this is what we would do, but it is slow for large matrices
      # > currentWU <- assignmat %*% scalingfactor
      # instead, we add the current task at the old scaling factor, then
      # add the difference to currentWU caused by the change in scaling
      currentWU[curtask] <- currentWU[curtask] + before.scaling
      currentWU <- currentWU +
        (scalingfactor[nodesel] - before.scaling) * assignmat[[nodesel]]
    } else {
      currentWU[curtask] <- currentWU[curtask] + 1
    }
  }

  list(currentWU = c(currentWU), assignment = data.frame(taskno = astaskno, node = asnode)[seq_len(iter), ])
}

# distribute tasks / learners on nodes: Get memory required
# for each using rbn.loadMemoryTableConfigured and solve the
# bin-packing problem.
#
# This is a nice fantasy but appears to be out of range with
# the optimizers available to us.
#
# We are optimizing the absolute difference between
# actual fraction of each learners used, and the
# requested proportion of each learner used (i.e.
# in the learner table), divided by the requested proportion,
# with the constraints:
# - memory used on each node is not larger than mempernode
# - memory used on each node is not smaller than mempernode minus
#   [smallest task/learner combination]
# - number of tasks per node is less than 96
# - every task X above 48 gives a performance hit:
#   Assuming hyper threading adds only 30% performance:
#   - 48 Tasks: 48 units of work
#   - 48 + X Tasks: 48 + 0.3 * X units of work
#   - Every single task: (48 + 0.3 * X) / (48 + X) units of work
#   --> piecewise linear approximation of that:
#     - 1 - 48 * m + X * m, m ~ -0.0084 (use linear model)
rbn.DistributeSrunsToNodes.MILP <- function(nodes, mempernode, physcores) {

  library("ompr")
  library("magrittr")
  physcores <- assertInt(physcores, coerce = TRUE)

  table <- rbn.compileParamTblConfigured()
  proptable <- aggregate(table$proportion, by = table["learner"], FUN = mean)

  learners <- proptable$learner
  lrnproportions <- proptable$x
  names(lrnproportions) <- learners
  data <- rbn.loadDataTableConfigured()$name

  fulltasks <- expand.grid(dataset = data, learner = learners, stringsAsFactors = FALSE)
  memcosts <- merge(fulltasks, rbn.loadMemoryTableConfigured(), all.x = TRUE)$memory_limit
  memcosts <- pmax(ceiling(memcosts / 1024) + 50, 350)
  memcosts[is.na(memcosts)] <- 2048

  proportions <- lrnproportions[fulltasks$learner]
  proportions <- proportions / sum(proportions)

  inverse.proportions <- 1 / proportions
  minmemcost <- min(memcosts)
  taskseq <- seq_along(memcosts)
  nodeseq <- seq_along(nodes)


  HTperfs <- (physcores + 0.3 * seq(0, physcores)) / seq(physcores, physcores * 2) - 1
  HTnums <- seq(0, physcores)
  weights <- 0.5 ^ seq(0, 1, length.out = physcores + 1)

  HTcost <- lm(HTperfs ~ 0 + HTnums, weights = weights)$coefficients[1]

  model <- MIPModel()

  # first part: minimize sum of absolute difference between required and
  # actual proportions, divided by these proportions
  #
  # this part depends on >>workunits[i]<<
  model <- model %>%
    add_variable(scaled.work.plus[i], i = taskseq, type = "continuous") %>%
    add_variable(scaled.work.minus[i], i = taskseq, type = "continuous") %>%
    add_variable(workunits[i], i = taskseq, type = "continuous") %>%
    add_constraint(scaled.work.plus[i] >= 0, i = taskseq) %>%
    add_constraint(scaled.work.minus[i] >= 0, i = taskseq) %>%
    add_constraint(scaled.work.plus[i] - scaled.work.minus[i] ==
      # the following is:
      # (workunits[i] - sum(workunits) * proportions[i]) / proportions[i]
      workunits[i] * inverse.proportions[i] - sum_expr(workunits[j], j = taskseq),
      i = taskseq) %>%
    set_objective(sum_expr(scaled.work.plus[i] + scaled.work.minus[i], i = taskseq),
      "min")

  # second part: instances i on each machine j add to workunits fully below
  # 48, less above that. NODE: not yet implemented, we always have full workunits
  #
  # this part depends on >>instances[i, j]<< and exports >>workunits[i]<<
  model <- model %>%
      add_variable(instances[i, j], i = taskseq, j = nodeseq, type = "integer") %>%
    add_constraint(instances[i, j] >= 0L, i = taskseq, j = nodeseq) %>%
    add_constraint(sum_expr(instances[i, j], i = taskseq) <= 2L * physcores,
      j = nodeseq) %>%
    add_constraint(workunits[i] == sum_expr(instances[i, j], j = nodeseq), i = taskseq)

  # the following does not work, because the performance of one job on a node
  # depends on hwo many other jobs are on that node. The
  # > instances[i, j] * perfscale[j]
  # line kills the whole thing.
    ## add_variable(perfscale[j], j = nodeseq, type = "continuous") %>%
    ## add_variable(inst.above.ht[j], j = nodeseq, type = "integer") %>%
    ## add_variable(inst.below.ht[j], j = nodeseq, type = "integer") %>%
    ## add_variable(htregime[j], j = nodeseq, type = "binary") %>%
    ## add_constraint(sum_expr(instances[i, j], i = taskseq) ==
    ##   physcores + inst.above.ht[j] - inst.below.ht[j], j = nodeseq) %>%
    ## add_constraint(inst.above.ht[j] >= 0L, j = nodeseq) %>%
    ## add_constraint(inst.below.ht[j] >= 0L, j = nodeseq) %>%
    ## add_constraint(inst.above.ht[j] <= physcores * htregime[j], j = nodeseq) %>%
    ## add_constraint(inst.below.ht[j] <= physcores * (1L - htregime[j]), j = nodeseq) %>%
    ## add_constraint(perfscale[j] == 1 + inst.above.ht[j] * HTcost, j = nodeseq) %>%
    ## add_constraint(workunits[i] ==
    ##   sum_expr(instances[i, j] * perfscale[j], j = nodeseq),
    ##   i = taskseq)

  #
  # third part: used memory smaller than available memory, bigger than
  # (available memory - smallest usable memory unit)
  model <- model %>%
    add_constraint(sum_expr(instances[i, j] * memcosts[i], i = taskseq) <= mempernode,
      j = nodeseq) %>%
    add_constraint(sum_expr(instances[i, j] * memcosts[i], i = taskseq) >=
      mempernode - minmemcost,
      j = nodeseq)

  library("ompr.roi")
  library("ROI")
  library("ROI.plugin.glpk")
  solution <- solve_model(model, with_ROI(solver = "glpk"))

  get_solution(solution, workunits[1])


}
