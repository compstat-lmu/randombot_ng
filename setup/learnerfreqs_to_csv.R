#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (!length(args)) {
  stop("Usage: parse_to_csv.R <infile.R>")
}

suppressMessages({
  library("ParamHelpers")
  library("mlrCPO")
})

sourceEnv <- function(file) {
  source(file = file, local = TRUE, echo = FALSE, chdir = TRUE)
  rm(file)
  as.list(environment())
}

pss <- sourceEnv(args[1])

pss <- pss[grepl("^prob\\.", names(pss))]
names(pss) <- gsub("^prob\\.", "", names(pss))

cat("learner\tproportion\n")
for (lname in names(pss)) {
  cat(sprintf("%s\t%s\n",
      lname,
      pss[[lname]]))
}
