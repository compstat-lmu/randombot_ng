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




# Parametrize this differently: 
task_data = read.csv("input/tasks.csv")  %>% mutate(data.id = as.integer(data.id))

ddf = df %>% 
  separate(dataset, c("data.name", "data.id"), "\\.(?=[^\\.][:digit:]*$)") %>%
  mutate(data.id = as.integer(data.id)) %>%
  full_join(task_data)

library(broom)
estimates = ddf %>%
  filter(!is.na(learner)) %>%
  group_by(learner, data.id) %>%
  filter(memorykb >= quantile(memorykb, 0.95, na.rm = TRUE)) %>%
  ungroup() %>%
  group_by(learner) %>%
  rename(n = number.of.instances, p = number.of.features, c = number.of.classes) %>%
  mutate(nsq = n^2, psq = p^2) %>%
  do(mod = lm(memorykb ~ n * p, data = .))


library(tidyr)
out = sapply(estimates$mod, predict,
  newdata = rename(
    filter(ddf, is.na(learner)),
    n = number.of.instances, p = number.of.features) %>% select(n, p))
out = data.frame(out)
colnames(out) = estimates$learner
out$dataset = datasets$dataset
gather(out, learner, memorykb, -dataset) %>% write.table("input/memory_requirementsp2.csv")




datasets = ddf %>%
 filter(is.na(learner)) %>%
 mutate(dataset = paste0(name, ".", data.id)) %>%
 select(dataset)


# Some initial script to obtain memory requirements for algorithms / datasets.
# We should extend this in the future.
library(dplyr)
library(tidyr)
library(ggplot2)
library(mlr)

memtab %>%
  group_by(dataset) %>%
  mutate(walltime = as.numeric(walltime)) %>%
  summarize(mn = mean(walltime), sd = sd(walltime), max = max(walltime)) %>%
  mutate(sd = if_else(is.na(sd), mean(sd, na.rm = TRUE), sd)) %>%
  mutate(weight = (mn/1000)^0.8) %>%
  mutate(prob = round(weight / sum(weight), 4)) %>%
  arrange(prob) %>%
  select(dataset, prob) %>%
  write.table("input/dataset_probs.csv")



# ----------------------------------------------------------------------------------------
# Some visual exploration of the data

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

learner_imp = data.frame(
  learner = c("classif.rpart", "classif.RcppHNSW", "classif.glmnet", "classif.svm.radial",
    "classif.ranger.pow", "classif.xgboost.gbtree", "classif.svm",
    "classif.xgboost.gblinear", "classif.xgboost.dart", "clasffi.kerasff"),
  importance = sqrt(c(4, 2, 1, 40, 240, 6000, 1.5, 120, 3000, 240))
)

# Weights
df %>%
  group_by(learner) %>%
  tally() %>%
  arrange(desc(n)) %>%
  mutate(
    frac = 1 / (n / sum(n)),
  ) %>%
  full_join(learner_imp) %>%
  mutate(
    frac = if_else(is.na(frac), 10, frac)
  ) %>%
  mutate(wt = sqrt(frac) * importance) %>%
mutate(wt = ceiling(wt / sum(wt) * 1000))






err = df %>%
  filter(errors.all) %>%
  group_by(errors.msg) %>%
  tally()

err$errors.msg[7]

p = df %>%
  filter(errors.msg == err$errors.msg[7]) %>%
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
dart = "dart"
gblinear = "gblinear"
gbtree = "gbtree"


# Error in ann$getNNsList(X[i, ], k, TRUE) : \n
# Unable to find k results. Probably ef or M is too small\n
pp = lapply(p$point, function(x) {eval(parse(text=x))})
pp = do.call(bind_rows, pp)
pp %>% summary()


p2 = df %>%
  filter(dataset == "KDDCup09_appetency.1111") %>%
  filter(!errors.all) %>% sample_frac(1)
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
