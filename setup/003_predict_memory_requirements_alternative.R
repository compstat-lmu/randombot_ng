library("data.table")

m1 <- readRDS("memtest1.rds")
m2 <- readRDS("memtest2.rds")

dewt <- function(wt)
  sapply(strsplit(wt, ":", TRUE), function(x)
    Reduce(function(x, y) x * 60 + y, as.numeric(x)))

m1$walltime <- dewt(m1$walltime)
m2$walltime <- dewt(m2$walltime)

m1red <- m1[, c("dataset", "learner", "seed", "memkb", "walltime")]
m2red <- m2[, c("dataset", "learner", "seed", "memkb", "walltime")]

allred <- merge(m1red, m2red, by = c("dataset", "learner", "seed"), all = TRUE)

allred$truememkb <- ifelse(is.na(allred$memkb.y), allred$memkb.x, allred$memkb.y)
allred$truewalltime <- ifelse(is.na(allred$walltime.y), allred$walltime.x, allred$walltime.y)

memreq <- allred[, list(memory_limit = 2.1 * quantile(truememkb, 0.9, na.rm = TRUE) - 0.9 * quantile(truememkb, 0.1, na.rm = TRUE)),
  by = c("dataset", "learner")]

write.table(as.data.frame(memreq), "memory_requirements.csv")

limo <- lm(I(log(truewalltime)) ~ 0 + dataset + learner, data = allred)

dscoef <- coef(limo)[grepl("^dataset", names(coef(limo)))]
names(dscoef) <- sub("^dataset", "", names(dscoef))

checkmate::checkSetEqual(names(dscoef), allred$dataset)

dsprobs <- data.table(dataset = names(dscoef), prob = exp(dscoef)^.6)

write.table(as.data.frame(dsprobs), "dataset_probs.csv")

# ---------------------------------------------------
# analysis of this

min(dsprobs$prob) / sum(dsprobs$prob)
max(dsprobs$prob) / sum(dsprobs$prob)

dsprobs[which.min(dsprobs$prob), ]
dsprobs[which.max(dsprobs$prob), ]

dsprobs <- allred[, list(prob = mean(truewalltime, na.rm = TRUE)^0.6), by = "dataset"]
summary(dsprobs)

ddx <- dsprobs[oldprobs, on = "dataset"]
plot(log(ddx$prob), log(ddx$i.prob))

lm(I(log(ddx$prob))~I(log(ddx$i.prob)))


dev.off()

allred[memreq, mean(truememkb >= memory_limit, na.rm = TRUE)]
m1red[memreq, mean(memkb >= memory_limit, na.rm = TRUE)]
m2red[memreq, mean(memkb >= memory_limit, na.rm = TRUE)]

oldari <- readRDS("allruninfodf.rds.xz")
oldari <- as.data.table(oldari)

oldari[memreq, mean(memorykb >= memory_limit, na.rm = TRUE), on = c("dataset", "learner")]

datasize <- allred[, .N, by = c("dataset", "learner")]



oldmemreq <- read.table("../development/R/randombot_ng/input/memory_requirements.csv")
oldmemreq <- as.data.table(oldmemreq)

oldprobs <- as.data.table(read.table("../development/R/randombot_ng/input/dataset_probs.csv"))

combinedmr <- merge(memreq, oldmemreq, by = c("dataset", "learner"), all = TRUE)

plot(datasize$N, log(combinedmr$memory_limit.x / combinedmr$memory_limit.y))

datasize


combinedmr[577]

plot(log(combinedmr$memory_limit.x), log(combinedmr$memory_limit.y))
abline(0, 1)

dev.off()






which(is.na(allred$truememkb))

mean(is.na(allred$memkb.x))
mean(is.na(allred$memkb.y))

