# load all libraries in the `R` directory
# This file must be sourced with `chdir = TRUE`

files = sort(list.files("R", pattern = "\\.[rR]$"))
for (f in file.path("R", files)) {
  source(f, chdir = TRUE)
}
