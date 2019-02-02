# RandomBot on SuperMUC NG ("Friendly User Phase")

[Notes Google Doc](https://docs.google.com/document/d/1Oe4V_GlDcDLQnzsix0yu6VBfpce9bzuquH3sZEOQZBE/edit?usp=sharing)

## Design Considerations

- Modular design with global settings that make it possible to switch different features on / off.
- Possible "Supererogatory" evaluations: More evaluation on the *same* point, with variations:
  - Different resampling splits ("RepCV").
  - Smaller training sets for "lerning curve".
  - Evaluation of the same point with only a single parameter changed.
- The learner and task are chosen deterministically which could make estimated needs based memory alocation possible.
- The SAME parameter configurations are all tried on different datasets to make dataset results comparable

## Script Organisation

- `main.R`: example of how different things are called / organised. Assumes `MUC_R_HOME` variable points to its home directory (because there is no stable way to query a running script's own directory). If you are using bash, you can run `. path/to/randombot_ng/scripts/export_muc_home.sh` (with the point in front) which does this.
- `source("load_all.R", chdir = TRUE)` to load R files.
- All interesting functions have prefix `rbn.`
- `Learners` can be registered (`rbn.registerLearner()`), so `rbn.getLearner(<LRN>)` gets the custom learner if it was registered, or `makeLearner(<LRN>, predict.type = "prob")` if not.
  - Register special learner function `"MODIFIER"` which gets called on each learner that gets retrieved, e.g. to attach a CPO.
- Global settings are set with `rbn.registerSetting()`, see `notes/notes.org` which ones are used by internals at various stages of flow.
- Parameter sampling: `rbn.compileParamTbl(<TBL.TSV>)` -> `rbn.sampleEvalPoint()` -> `rbn.parseEvalPoint()` -> `resample` (or whatever).
  - Sampling can happen on main node, or within worker threads.

### Input Parameters

- Set global parameters using `rbn.registerSetting()`
- Parameter space is given as `.tsv` (tab-separated) file.
- Custom learners can be registered using 'rbn.registerLearner'.
- Custom learner "MODIFIER" is a unary function that can attach CPOs.

