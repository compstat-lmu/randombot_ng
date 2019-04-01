#!/usr/bin/env Rscript
# This script drains results from the RESULTQUEUE queue in redis into
# batches of 1000 into files named RESULTS/<nodename>/OUT/<xx>/<xx>/<xxxx...>
# where <xx> are digits in the digest::digest().

# get info about the running instance from environment
suppressPackageStartupMessages({
  library("BBmisc")
  library("redux")
})
options(warn=1)
r.host <- Sys.getenv("REDISHOST")
r.port <- Sys.getenv("REDISPORT")
r.pass <- Sys.getenv("REDISPW")
r.port <- as.integer(r.port)
nodename <- Sys.getenv("SLURMD_NODENAME")
runindex <- as.integer(Sys.getenv("SLURM_PROCID")) + 1  # we use 1-based index
maxrunindex <- as.integer(Sys.getenv("SLURM_NPROCS"))

# if we are just supposed to drain the last few bits the first argument should be
# "NOBLOCK". In that case we exit when we're done.
noblock <- c(commandArgs(trailingOnly = TRUE), "")[1] == "NOBLOCK"

# say hi to everyone
catf("[%s] drainredis.R started %s out of %s on node %s in %s mode",
  runindex, runindex, maxrunindex, nodename, if (noblock) "nonblocking" else "blocking")

# connect to redis
rcon <- NULL
catf("[%s] Connecting to redis %s:%s", runindex, r.host, r.port)
rcon <- hiredis(host = r.host, port = r.port, password = r.pass)

# there is one queue RESULTQUEUE that the different threads write into, and
# different PENDING_x queues for each running thread.
incomingqueue <- "RESULTS"
allpending <- sprintf("PENDING_%s", seq_len(maxrunindex))
ownpending <- allpending[runindex]

# We drain the PENDING_x queues that did not get finished in the last run
catf("[%s] Draining leftover queues", runindex)
while (!is.null(rcon$RPOPLPUSH(ownpending, incomingqueue))) { }

# If we are the highest index run, we also drain the queues with index
# higher than the one currently running, in case something was run
# previously that had more draining instances.
if (runindex == maxrunindex) {
  foundqueues <- setdiff(unlist(rcon$KEYS("PENDING_*")), allpending)
  catf("[%s] Draining %s queues beyond my own", runindex, length(foundqueues))
  for (fq in foundqueues) {
    while (!is.null(rcon$RPOPLPUSH(fq, incomingqueue))) { }
    stopifnot(isTRUE(rcon$LLEN(fq) == 0))
  }
}

# check that our queue is drained
stopifnot(isTRUE(rcon$LLEN(ownpending) == 0))

catf("[%s] Ready for action. Waiting for %s and caching in %s",
  runindex, incomingqueue, ownpending)

repeat {
  # get 1000 results, but also store them in PENDING_x
  if (noblock) {
    tosave <- replicate(1000, rcon$RPOPLPUSH(incomingqueue, ownpending),
      simplify = FALSE)
    tosave <- lapply(Filter(Negate(is.null), tosave), unserialize)
    if (!length(tosave)) {
      break
    }
  } else {
    tosave <- replicate(1000,
      unserialize(rcon$BRPOPLPUSH(incomingqueue, ownpending, timeout = 0)),
      simplify = FALSE)
  }

  fname <- digest::digest(tosave)
  prefix1 <- substr(fname, 1, 2)
  prefix2 <- substr(fname, 3, 4)
  outdir <- file.path("RESULTS", nodename, "OUT", prefix1, prefix2)
  outfile <- file.path(outdir, fname)

  # create output dir if it does not exist yet
  dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

  # save with highest compression. Otherwise postprocessing is annoying.
  # We save to <filename>.tmp first, in case our process gets killed in-flight.
  catf("[%s] Saving %s results to %s", runindex, length(tosave), fname)
  saveRDS(tosave, paste0(outfile, ".tmp"), compress = "xz")
  file.rename(paste0(outfile, ".tmp"), outfile)

  # if we got here then everything is savely on disk and we delete the result
  # from the PENDING_x queue.
  # There is a small chance that we get killed here and as a result some run
  # results get written out twice, but we will live with that.
  rcon$DEL(ownpending)
}

if (!noblock) {
  stopf("[%s] GOT TO UNREACHABLE CODE", runindex)
}


