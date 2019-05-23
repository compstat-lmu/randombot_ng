#!/usr/bin/env Rscript

indir <- "RESULTS"
options(warn=1)
suppressPackageStartupMessages({
  library("data.table")
  library("mlr")
})

outfiles <- list.files(indir, recursive = TRUE, full.names = TRUE, include.dirs = FALSE)
outfiles <- grep("\\.tmp$", outfiles, value = TRUE, invert = TRUE)

result.to.table <- function(filename) {
  content <- readRDS(filename)
  rbindlist(lapply(content, function(rres) {
    lname <- rres$METADATA$learner
    tname <- rres$METADATA$task
    seed <- rres$METADATA$seed
    stopifnot(is.finite(seed) && round(seed) == seed)
    point <- rres$METADATA$point

    stopifnot(isTRUE(rres$learner.id == lname))
    stopifnot(isTRUE(rres$task.id == tname))

    naresults <- aggregate(is.na(rres$pred$data$response), by = list(iter = rres$pred$data$iter), FUN = any)$x

    list(
      dataset = tname,
      learner = lname,
      point = point,
      seed = seed,
      evals = nrow(rres$measures.test),
      perf.mmce = performance(rres$pred, list(mlr::mmce)),
      perf.logloss = performance(rres$pred, list(mlr::logloss)),
      traintime = sum(rres$measures.test$timetrain),
      predicttime = sum(rres$measures.test$timepredict),
      totaltime = rres$runtime,
      errors.num = sum(naresults),
      errors.all = all(naresults),
      errors.any = any(naresults),
      errors.msg = c(na.omit(c(t(as.matrix(rres$err.msgs[c("train", "predict")])))), NA)[1]
    )
  }))
}

alltable <- rbindlist(parallel::mclapply(outfiles, result.to.table, mc.cores = 70))

saveRDS(alltable, "TABLE/evalresult.rds")
