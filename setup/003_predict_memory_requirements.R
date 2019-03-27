# Some initial script to obtain memory requirements for algorithms / datasets.
# We should extend this in the future.
library(dplyr)
library(tidyr)
library(ggplot2)
library(mlr)
# library(OpenML)

memtab = read.table("~/Downloads/memtable", header = TRUE)
memtab %>%
  group_by(dataset, learner) %>%
  summarize(mn = mean(memorykb), sd = sd(memorykb), max = max(memorykb)) %>%
  ungroup() %>%
  arrange(desc(max)) %>%
  mutate(sd = if_else(is.na(sd), max(sd, na.rm = TRUE), sd)) %>%
  mutate(memory_limit = max + 0.5 * sd) %>%
  select(dataset, learner, memory_limit) %>%
  separate(dataset, c("name", "data.id"), "\\.(?=[^\\.][:digit:]*$)") %>%
  write.table("input/memory_requirements.csv")




#-----------------------------------------------------------------------------------------
# tasks = read.csv("input/tasks.csv")
# tab = memtab %>%
#   separate(dataset, c("name", "data.id"), "\\.(?=[^\\.][:digit:]*$)") %>%
#   select(memorykb, data.id, learner) %>%
#   mutate(data.id = as.numeric(data.id)) %>%
#   left_join(tasks, on = "data.id") %>%
#   select(memorykb, data.id, learner, number.of.classes:number.of.instances) %>%
#   mutate(data.id = factor(data.id))
# tsk = makeRegrTask(data = tab, target = "memorykb")
# lrn = makeLearner("regr.cubist")
# mod = resample(lrn, tsk, hout)

# ggplot(memtab) +
#   geom_density(aes(x = memorykb, color = learner)) +
#   facet_wrap(~dataset, scales = "free") +
#   theme(
#     axis.title = element_blank(),
#     axis.ticks = element_blank(),
#     axis.text = element_blank(),
#     title = element_blank()
#   )

# memtab %>%
#   group_by(learner) %>%
#   summarize(mn = mean(memorykb), sd = sd(memorykb), max = max(memorykb))

# memtab %>%
#   group_by(dataset) %>%
#   summarize(mn = mean(memorykb), sd = sd(memorykb), max = max(memorykb)) %>%
#   top_n(10, max) %>%
#   ggplot() + geom_point(aes(x = 1, y = max, color = dataset))



# mod <-lm(1:150 ~ ., iris)
# summary(mod) -> a
# mod$
