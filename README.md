# RandomBot on SuperMUC NG ("Friendly User Phase")

[Notes Google Doc](https://docs.google.com/document/d/1Oe4V_GlDcDLQnzsix0yu6VBfpce9bzuquH3sZEOQZBE/edit?usp=sharing)

## Design Considerations

- Modular design with global settings that make it possible to switch different features on / off.
- Possible "Supererogatory" evaluations: More evaluation on the *same* point, with variations:
  - Different resampling splits (`RepCV`).
  - Smaller training sets for "learning curve".
  - All this is captured by just creating a set of resampling instances
- The learner and task are chosen deterministically which could make estimated needs based memory alocation possible.
- The SAME parameter configurations are all tried on different datasets to make dataset results comparable
- Scheduling with [redis](https://redis.io/)

## General Principles

- `source("load_all.R", chdir = TRUE)` to load all `/R/` files
- All interesting functions have prefix `rbn.`
- Settings are in `/input/` directory; `custom_learners.R` and `constants.R` should be `source()`d with `chdir = TRUE`.
- `Learners` can be registered (`rbn.registerLearner()`), so `rbn.getLearner(<LRN>)` gets the custom learner if it was registered, or `makeLearner(<LRN>, predict.type = "prob")` if not.
  - Register special learner function `"MODIFIER"` which gets called on each learner that gets retrieved, e.g. to attach a CPO.
- Global settings are set with `rbn.registerSetting()`, see `notes/notes.org` which ones are used by internals at various stages of flow.
- Parameter sampling: `rbn.compileParamTbl(<TBL.TSV>)` -> `rbn.sampleEvalPoint()` -> `rbn.evaluatePoint()`

## Input Parameters

- See detailed info on parameters passed through control flow in `/notes/notes.org`
- Set global parameters using `rbn.registerSetting()`
- Parameter space is given as `.tsv` (tab-separated) file. Can easily be edited with Excel or Calc. Following columns:
  - **`learner`**: Learner name, as can be found in `mlr` or registered using `rbn.registerLearner()`.
  - **`parameter`**: Parameter name, ID in the `Learner`'s ParamSet. Can also include a CPO parameter if a CPO gets attached in custom learner or through `"MODIFIER"`.
  - **`values`**: If the parameter is discrete (not logical), list of values to try, comma-separated. This may be a single value (independent of type) to set the parameter to that value
  - **`lower`**, **`upper`**: lower and upper bound for numeric / integer parameters, pre-transformation
  - **`trafo`**; transformation function. An expression that gets pasted inside `function(x) { ... }`, so should be an expression of `x`.
  - **`requires`**: Parameter requirement. Gets converted using `BBmisc::asQuoted`.
  - **`condition`**: Optional expression that gets evaluated inside `function(x, n, p) { ... }`, where `x` is the sampled parameter value, `n` is the number of rows and `p` the number of features of a task (maybe we have to think about CPO trafos that change column number). If this returns `FALSE`, the point is not evaluated. Can for example be used if something must not be greater than half the number of features.
- Custom learners can be registered using `rbn.registerLearner`.
- Custom learner `"MODIFIER"` is a unary function that can attach CPOs.

## Script Organisation

### Settings
Settings for runs should be collected in the `/input/` directory.

* **`constants.R`**: contains global constant settings
* **`custom_learners.R`**: defines learners to use, and sources files in the `/input/learners/` directory
* **`paramsets.R`**: definition of parameter spaces in the form of `ParamHelpers::ParamSet` objects
* **`tasks.csv`**: Task description
* **`spaces.csv`**: Search space (generated by `parse_to_csv.sh`)

### Data Preparation (developer machine)
Data preparation with scripts in `/setup/`:

1. **`parse_to_csv.sh`**: Read in `paramsets.R` and pipe result to `spaces.csv`.
2. **`collect_data.R`**: Retrieve data and write `/data/LEARNERS`, `/data/TASKS` as well as data `*.rds.gz` files.
3. **`create_inputs.sh`**: Create input value table for "perparam" scheduling mode into `/data/INPUTS`
4. Move content of `/data/` directory to login node

### Cluster Preparation (login node)
Preparation of work environment, using `/setup/` files:

1. **`001_install_pkgs.R`**: installing `R` environment
2. **`setup.recipe`**: description and explanation of environment variable setup

### Evaluations
To start evaluations, call `invoke_sbatch.sh` in the `/scheduling/` directory.

1. **`invoke_sbatch.sh`**: called by the user, calls `sbatch` with `sbatch.cmd`
2. **`sbatch.cmd`**: starts `srun` job-steps with `runscript.sh`
3. **`runredis.sh`**: start redis-server instance that distributes tasks (seeds) to evaluate and collects results
4. **`drainredis.R`**: gets results from redis and saves them to disk via `saveRDS`.
5. **`runscript.sh`**: runs `eval_redis.R` on the computation nodes
6. **`eval_redis.R`**: R script that performs resampling

Some helper-scripts

- **`commons.sh`**: checking environment variables for consistency
- **`drainredis_manual`**: call `drainredis.R` manually to collect last few results stuck in redis server
- **`eval_single.R`**: left over from before redis was used, may be useful for manual evaluation of runs
- **`sample_learners.R`**: sample from learner table according to their `proprortions.csv`

### R Script Internals
Mostly in `/R/` directory, with exception of `load_all.R`.

- **`load_all.R`**: `source()`s all files from `/R/` directory
- **`000_setup.R`**: Loaded first and loads libraries, makes some global configurations
- **`get_setting.R`**: Accessing global settings defined mostly in `/input/constants.R`.
- **`get_data.R`**: Functions that retrieve data and handle table of available datasets, interplays with `/input/tasks.csv` and `/data/`.
- **`get_learner.R`**: Functions for definition and retrieval of learners, interplays with `/input/custom_learners.R`.
- **`tables_loader.R`**: Loading parameter space data
- **`check_param_tbl.R`**: Checking parameter space data
- **`sample_eval_point.R`**: Sampling parameters for evaluation; used either on developer-machine in `/setup/create_inputs.sh` (for scheduling mode "perparam") as well as on cluster in `eval_redis.R`.
- **`parse_eval_point.R`**: Going from `character[1]` value, emitted by `sample_eval_point.R`, to actual parameter list
- **`evaluate_point.R`**: Calling resampling
- **`write_results.R`**: Writing out results
- **`resampling_tools.R`**: Auxiliary functions for handling `ResampleInstance` objects

## Benchmark Setup:

### Datasets
OpenML CC-18 + AutoML Datasets; ~115 Datasets in Total

[Tasks](https://docs.google.com/spreadsheets/d/1IlcB98LZsG9y6veYivH05mN4yC8Qf2y2kB2HZHPsaMI/edit?usp=sharing)

### Learners
- xgboost (xgboost)
- svm (e1071) [LibSVM]
- random forest (ranger)
- rpart (rpart)
- Glmnet (glmnet)
- Approximate Nearest Neighbours (RcppHNSW) wrapps [https://github.com/nmslib/hnswlib]
- Keras Fully Connected NNs up to 4 layers / 1024 neurons.

### Hyperparam Spaces

Current spaces: [Parameter Set](https://github.com/compstat-lmu/randombot_ng/blob/master/input/paramsets.R)

We currently sample numerics using the following strategy:
  1. compute m = (upper - lower) / 2
  2. sample x from N(m, m^2) (i.e. our bounds are mu +/- 1 * sigma)
  3. if x out of technical bounds go back to 2., else return x

Integers and discrete variables are sampled with equal probabilities.

## Evaluation Strategies
- 10-fold stratified CV [OpenML Tasks]
- Additionally, in 10% of all points:
  - 10 x 10-fold stratified CV [OpenML Tasks]
  - Subsampling [Subsampled OpenML Tasks]


# We are very open to suggestions by everyone! Feel free to message us or create an issue.
