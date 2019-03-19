library(OpenML)
setOMLConfig(cachedir = "~/Documents/projects/oml_cache")


data  = read.csv("~/Downloads/rbng.csv")
oml18 = listOMLTasks(tag = "OpenML-CC18")

t18 = oml18[!(oml18$task.id %in% data$task.id_cv10), ]

write.csv(file = "~/t18.csv", t18)



for (i in 10:14) {
  t = listOMLTasks(data.name = t18$name[i])
  ti = t[( t$task.type == "Supervised Classification" &
      t$data.id == t18$data.id[i] &
      t$estimation.procedure == "10 times 10-fold Crossvalidation"), ]
  print(ti[, c("task.id", "data.id", "name", "number.of.classes")])
}

# Check whether all datasets / tasks are in the cachedir
setdiff(as.character(data$data.id), list.files("~/Documents/projects/oml_cache/datasets"))
setdiff(as.character(data$task.id_cv10), list.files("~/Documents/projects/oml_cache/tasks"))
setdiff(as.character(data$task.id_10cv10), list.files("~/Documents/projects/oml_cache/tasks"))

for (i in 168871:168875) getOMLTask(i)
