# pkg_dir  = "/home/flo/Documents/repos/r_pkgs_randombotng" # Download packages
repo_dir = "/naslx/projects/pr74ze/di25pic2/randombot_files/r_drat" # Cran-like repo folder


pkgs = c("e1071", "xgboost", "ranger", "rpart", "LiblineaR", "glmnet", "mlr",
  "farff", "mlrMBO", "batchtools", "digest", "mlrCPO", "checkmate")

## Preparation:
## Download all packages from CRAN to a PKG_DIR and save them into a REPO_DIR.
## REPO_DIR can now act like a offline CRAN Mirror.
# install.packages("drat")
# require(drat)
# down_pkg_deps = function(pkg, destdir,
#   which = c("Depends", "Imports", "LinkingTo"),
#   inc.pkg = TRUE, repos = getOption("repos")) {
#   stopifnot(require("tools")) ## load tools
#   ap = available.packages(repos = repos) ## takes a minute on first use
#   ## get dependencies for pkg recursively through all dependencies
#   deps = package_dependencies(pkg, db = ap, which = which, recursive = TRUE)
#   ## the next line can generate warnings; I think these are harmless
#   ## returns the Priority field. `NA` indicates not Base or Recommended
#   pri <- sapply(deps[[1]], packageDescription, fields = "Priority")
#   ## filter out Base & Recommended pkgs - we want the `NA` entries
#   deps <- deps[[1]][is.na(pri)]
#   ## install pkg too?
#   if (inc.pkg) {
#     deps = c(pkg, deps)
#   }
#   download.packages(deps, destdir = destdir)
#   deps ## return dependencies
# }
# down_pkg_deps("mlrCPO", destdir = pkg_dir)
# pkgs = list.files(pkg_dir, full.names = TRUE)
# sapply(pkgs, function(x) {drat::insertPackage(x, repo_dir)})


#--------------------------------------------------------------------------------------
## Install step:
## Installs all packages from REPO_DIR
## REPO_DIR can act like a offline CRAN Mirror.
inst_pkg_deps = function(pkg, install = TRUE,
  which = c("Depends", "Imports", "LinkingTo"),
  inc.pkg = TRUE, repos = getOption("repos")) {
  stopifnot(require("tools")) ## load tools
  ap = available.packages(repos = repos) ## takes a minute on first use
  ## get dependencies for pkg recursively through all dependencies
  deps = package_dependencies(pkg, db = ap, which = which, recursive = TRUE)
  ## the next line can generate warnings; I think these are harmless
  ## returns the Priority field. `NA` indicates not Base or Recommended
  pri <- sapply(deps[[1]], packageDescription, fields = "Priority")
  ## filter out Base & Recommended pkgs - we want the `NA` entries
  deps <- deps[[1]][is.na(pri)]
  ## install pkg too?
  if (inc.pkg) {
    deps = c(pkg, deps)
  }
  ## are we installing?
  if (install) {
    install.packages(deps, repos = repos)
  }
  deps ## return dependencies
}

# Update already existing packages
update.packages(repos = paste0("file:", repo_dir), ask = FALSE, lib.loc = Sys.getenv("R_LIBS_USER"))
inst_pkg_deps("e1071",     repos = paste0("file:", repo_dir))
inst_pkg_deps("xgboost",   repos = paste0("file:", repo_dir))
inst_pkg_deps("rpart",     repos = paste0("file:", repo_dir))
inst_pkg_deps("LiblineaR", repos = paste0("file:", repo_dir))
inst_pkg_deps("ranger",    repos = paste0("file:", repo_dir))
inst_pkg_deps("glmnet",    repos = paste0("file:", repo_dir))
inst_pkg_deps("mlr",       repos = paste0("file:", repo_dir))
inst_pkg_deps("mlrMBO",    repos = paste0("file:", repo_dir))
inst_pkg_deps("farff",     repos = paste0("file:", repo_dir))
inst_pkg_deps("batchtools",repos = paste0("file:", repo_dir))
inst_pkg_deps("mlrCPO",    repos = paste0("file:", repo_dir))
