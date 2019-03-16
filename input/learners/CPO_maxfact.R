

cpoMaxFact <- makeCPO("max.fact",
  pSS(max.fact.no = .Machine$integer.max: integer[1, ]),
  fix.factors = TRUE,
  dataformat = "factor",
  cpo.train = {
    sapply(data, function(d) {
      if (length(levels(d)) < max.fact.no - 1) {
        return(levels(d))
      }
      c(names(sort(table(d), decreasing = TRUE))[seq_len(max.fact.no - 1)],
        rep("collapsed", length(levels(d)) - max.fact.no + 1))
    }, simplify = FALSE)
  },
  cpo.retrafo = {
    for (n in names(data)) {
      levels(data[[n]]) = control[[n]]
    }
    data
  })
