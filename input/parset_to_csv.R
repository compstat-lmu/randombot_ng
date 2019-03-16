#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (!length(args)) {
  stop("Usage: parse_to_csv.R <infile.R>")
}

library("ParamHelpers")

sourceEnv <- function(file) {
  source(file = file, local = TRUE, echo = FALSE, chdir = TRUE)
  rm(file)
  as.list(environment())
}

pss <- sourceEnv(args[1])

parfix.lg <- grepl("\\.fixed_pars$", names(pss))

pardef <- pss[!parfix.lg]
parfix <- pss[parfix.lg]

names(parfix) <- sub("\\.fixed_pars$", "", names(parfix))

stopifnot(all(names(parfix) %in% names(pardef)))

cat("learner\tparameter\tvalues\tlower\tupper\ttrafo\trequires\tcondition\n")
for (lname in names(pardef)) {
  parset <- pardef[[lname]]
  for (pname in getParamIds(parset)) {
    par <- parset$pars[[pname]]
    val <- ""
    low <- ""
    up <- ""
    trafo <- ""
    req <- ""
    if (isDiscrete(par, include.logical = FALSE)) {
      val <- paste(names(par$values), collapse = ", ")
    } else if (isNumeric(par)) {
      low <- par$lower
      up <- par$upper
    }
    if (!is.null(par$trafo)) {
      trafo <- deparse(par$trafo, width.cutoff = 500)
      stopifnot(length(trafo) == 2)
      trafo <- trafo[2]
    }
    if (!is.null(par$requires)) {
      req <- deparse(par$requires, width.cutoff = 500)
      stopifnot(length(req) == 1)
    }
    cat(sprintf("%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
      lname,
      pname,
      val,
      low,
      up,
      trafo,
      req,
      ""))
  }
  parf <- parfix[[lname]]
  for (fixname in names(parf)) {
    cat(sprintf("%s\t%s\t%s\t\t\t\t\t\n",
      lname, fixname, parf[[fixname]]))
  }
}
