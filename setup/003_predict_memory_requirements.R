# Some initial script to obtain memory requirements for algorithms / datasets.
# We should extend this in the future.
library(dplyr)
library(tidyr)
library(ggplot2)
library(mlr)
# library(OpenML)

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
