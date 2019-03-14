makeRLearner.classif.LiblineaR = function() {
  makeRLearnerClassif(
    cl = "classif.LiblineaR",
    package = "LiblineaR",
    par.set = makeParamSet(
      makeIntegerLearnerParam(id = "type", default = 5L, lower = 0L, upper = 7L),
      makeNumericLearnerParam(id = "cost", default = 1, lower = 0),
      makeNumericLearnerParam(id = "epsilon", default = 0.01, lower = 0),
      makeLogicalLearnerParam(id = "bias", default = TRUE),
      makeNumericVectorLearnerParam(id = "wi", len = NA_integer_),
      makeIntegerLearnerParam(id = "cross", default = 0L, lower = 0L, tunable = FALSE),
      makeLogicalLearnerParam(id = "verbose", default = FALSE, tunable = FALSE)
    ),
    properties = c("twoclass", "multiclass", "numerics", "class.weights"),
    class.weights.param = "wi",
    name = "Liblinear Support Vector Classification",
    short.name = "liblineaR",
    callees = "LiblineaR"
  )
}

#' @export
trainLearner.classif.LiblineaR = function(.learner, .task, .subset, .weights = NULL, ...) {
  d = getTaskData(.task, .subset, target.extra = TRUE)
  LiblineaR::LiblineaR(data = d$data, target = d$target, ...)
}

#' @export
predictLearner.classif.LiblineaR = function(.learner, .model, .newdata, ...) {
    as.factor(predict(.model$learner.model, newx = .newdata, ...)$predictions)
}


# 0 – L2-regularized logistic regression (primal)
# 1 – L2-regularized L2-loss support vector classification (dual)
# 2 – L2-regularized L2-loss support vector classification (primal)
# 3 – L2-regularized L1-loss support vector classification (dual)
# 4 – support vector classification by Crammer and Singer
# 5 – L1-regularized L2-loss support vector classification
# 6 – L1-regularized logistic regression
# 7 – L2-regularized logistic regression (dual)
# Type 0, 6, 7 can do "probs"
