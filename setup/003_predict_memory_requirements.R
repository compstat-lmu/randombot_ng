# Some initial script to obtain memory requirements for algorithms / datasets.
# We should extend this in the future.
library(dplyr)
library(tidyr)
library(ggplot2)
library(mlr)
library(patchwork)

# memtab = read.table("~/Downloads/memtable", header = TRUE)
# mm  = memtab %>%
#   group_by(dataset, learner) %>%
#   summarize(mn = mean(memorykb), sd = sd(memorykb), max = max(memorykb)) %>%
#   ungroup() %>%
#   mutate(sd = if_else(is.na(sd), max(sd, na.rm = TRUE), sd)) %>%
#   mutate(memory_limit = max + 0.8 * sd) %>%
#   select(dataset, learner, memory_limit) # %>%
#   # separate(dataset, c("name", "data.id"), "\\.(?=[^\\.][:digit:]*$)")
# # write.table(mm, "input/memory_requirements.csv")


df = readRDS("~/Downloads/allruninfodf.rds")
# Optimize memory :)
mm = df %>%
  group_by(dataset, learner) %>%
  filter(!is.na(memorykb)) %>%
  summarize(mn = mean(memorykb), sd = sd(memorykb), max = max(memorykb), q9 = quantile(memorykb, 0.9), q1 = quantile(memorykb, 0.1)) %>%
  ungroup() %>%
  mutate(sd = if_else(is.na(sd), max(sd, na.rm = TRUE), sd)) %>%
  mutate(memory_limit = 2.1*q9 - 0.9*q1) %>%
  select(dataset, learner, memory_limit)
write.table(mm, "input/memory_requirements.csv")


df %>%
  group_by(learner, dataset) %>%
  filter(!is.na(memorykb)) %>%
  summarize(memorykb = median(memorykb)) %>%
  group_by(learner) %>%
  summarize(mean(memorykb))

p1 = df %>%
  group_by(dataset) %>%
  tally() %>%
  arrange(desc(n)) %>%
  ggplot(aes(x = dataset, y = n)) +
    geom_bar(stat = "identity") +
    theme(axis.text.x = element_blank()) +
    ggtitle("Evals per Task")

  # filter(learner == "classif.xgboost.dart") %>%
p2 = df %>%
  group_by(dataset) %>%
  summarize(wt = sum(walltime, na.rm = TRUE)) %>%
  ggplot(aes(x = dataset, y = wt)) +
    geom_bar(stat = "identity") +
    theme(axis.text.x = element_blank()) +
    ggtitle("Walltime per task")

ggsave((p1 + p2), filename = "../evals_runs_per_dataset.pdf")


p1 = df %>%
  group_by(learner) %>%
  tally() %>%
  arrange(desc(n)) %>%
  ggplot(aes(x = learner, y = n, fill = learner)) +
    geom_bar(stat = "identity") +
    theme(axis.text.x = element_blank()) +
    ggtitle("Evals per Task") +
    guides(fill = FALSE)

  # filter(learner == "classif.xgboost.dart") %>%
p2 = df %>%
  group_by(learner) %>%
  summarize(wt = sum(walltime, na.rm = TRUE)) %>%
  ggplot(aes(x = learner, y = wt, fill = learner)) +
    geom_bar(stat = "identity") +
    theme(axis.text.x = element_blank()) +
    ggtitle("Walltime per task")

ggsave((p1 + p2), filename = "../evals_runs_per_learner.pdf")






err = df %>%
  filter(errors.all) %>%
  group_by(errors.msg) %>%
  tally()

p = df %>%
  filter(errors.msg == err$errors.msg[6]) %>%
  filter(errors.all)

p %>% group_by(dataset) %>% tally()

cosine = "cosine"
l2 = "l2"
ip = "ip"
impute.hist = "impute.hist"
impute.median = "impute.median"
impute.mean = "impute.mean"
radial = "radial"
linear = "linear"
polynomial = "polynomial"
ignore = "ignore"
gini = "gini"
partition = "partition"
extratrees = "extratrees"
order = "order"


# Error in ann$getNNsList(X[i, ], k, TRUE) : \n
# Unable to find k results. Probably ef or M is too small\n
pp = lapply(p$point, function(x) {eval(parse(text=x))})
pp = do.call(bind_rows, pp)
pp %>% summary()


p2 = df %>%
  filter(learner %in% c("classif.RcppHNSW")) %>%
  filter(!errors.all) %>% sample_frac(0.001)
pp2 = lapply(p2$point, function(x) {eval(parse(text=x))})
pp2 = do.call(bind_rows, pp2)

pp3 = bind_rows("fail" = pp, "sail" = pp2, .id = "type")

tt = pp3 %>% mutate(
    # shrinking = as.factor(shrinking),
    num.impute.selected.cpo = as.factor(num.impute.selected.cpo),
    # fitted = as.factor(fitted),
    # kernel = as.factor(if_else(is.na(kernel), "radial", kernel))
  ) %>%
  select(-SUPEREVAL, -distance) %>%
  ungroup() %>% data.frame() %>%
  makeClassifTask(id = "df", target = "type")

m = train(makeLearner("classif.rpart"), tt)
rpart.plot::rpart.plot(m$learner.model)

ggplot(pp3, aes(y = cost, x = gamma, color = type),
    alpha = 0.7) +
  geom_point() +
  geom_jitter() +
  coord_cartesian(xlim = c(0,2), ylim = c(0, 2)) +
  facet_wrap(~kernel)
# M > 20: No errors
head(pp3[, 6:8])
