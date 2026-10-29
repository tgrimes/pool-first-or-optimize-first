# The application: serum cotinine and current smoking among NHANES adults,
# 2013 to 2018 (protocol.md; analysis/02_application.R). The procedure is
# MiYoudenInference(), with predictive mean matching on the participants'
# characteristics in place of the simulation's single auxiliary.

#' Education and income categories from an NHANES demographics file
#'
#' Codes as printed in the `DEMO_H`, `DEMO_I`, and `DEMO_J` codebooks (read
#' 2026-10-29): `DMDEDUC2`, asked of adults 20 and over, 1 less than 9th
#' grade, 2 9th to 11th grade, 3 high school graduate or GED, 4 some
#' college or AA degree, 5 college graduate or above, 7 refused, 9 don't
#' know; `INDFMPIR`, the ratio of family income to poverty, 0 to 4.99, and
#' 5 for 5.00 or more. Refused, don't know, missing, and the 18- and
#' 19-year-olds not asked are put in an "unknown" category, so that every
#' participant has a value.
#'
#' @param demo A data frame read from a `DEMO` file.
#' @return A data frame with `seqn`, `educ`, and `income`.
#' @export
EducationIncome <- function(demo) {
  e <- demo$DMDEDUC2
  educ <- ifelse(e %in% c(1, 2), "less than high school",
                 ifelse(e %in% 3, "high school",
                        ifelse(e %in% 4, "some college",
                               ifelse(e %in% 5, "college graduate",
                                      "unknown"))))
  r <- demo$INDFMPIR
  income <- ifelse(is.na(r), "unknown",
                   ifelse(r < 1, "below 1",
                          ifelse(r < 2, "1 to 2",
                                 ifelse(r < 4, "2 to 4", "4 or more"))))
  data.frame(seqn = demo$SEQN, educ = educ, income = income,
             stringsAsFactors = FALSE)
}

#' The application's cohort: all three cycles, with education and income
#'
#' @param raw_dir Folder holding the downloaded `.xpt` files.
#' @return The rows of `ReadNhanesCycle()` for the three cycles, with
#'   `educ` and `income` from `EducationIncome()`.
#' @export
ReadApplicationCohort <- function(raw_dir) {
  files <- NhanesFiles()
  cycles <- unique(files[, c("cycle", "suffix")])
  do.call(rbind, lapply(seq_len(nrow(cycles)), function(i) {
    cohort <- ReadNhanesCycle(raw_dir, cycles$suffix[i], cycles$cycle[i])
    demo <- foreign::read.xport(file.path(
      raw_dir, paste0("DEMO_", cycles$suffix[i], ".xpt")))
    merge(cohort, EducationIncome(demo), by = "seqn", sort = FALSE)
  }))
}

#' Predictors of the cotinine imputation model
#'
#' Smoking status, age and its square (centred and scaled), sex, and their
#' interactions with smoking status, with indicators of race/ethnicity,
#' cycle, education, and income (first level left out).
#'
#' @param cohort A data frame with `smoker`, `age`, `sex`, `race`, `cycle`,
#'   `educ`, and `income`.
#' @param drop Names of the factors to leave out (for example `"race"`
#'   within a race/ethnicity stratum).
#' @return A numeric matrix, one row per participant, no intercept.
#' @export
CotininePredictors <- function(cohort, drop = character(0)) {
  age <- (cohort$age - 50) / 15
  male <- as.numeric(cohort$sex == "male")
  d <- cohort$smoker
  out <- cbind(d = d, age = age, age2 = age^2, male = male,
               d_age = d * age, d_male = d * male)
  for (f in setdiff(c("race", "cycle", "educ", "income"), drop)) {
    lev <- sort(unique(cohort[[f]]))
    if (length(lev) > 1) {
      ind <- vapply(lev[-1], function(l) as.numeric(cohort[[f]] == l),
                    numeric(nrow(cohort)))
      ind <- matrix(ind, nrow = nrow(cohort))
      colnames(ind) <- paste0(f, "_", seq_len(ncol(ind)))
      out <- cbind(out, ind)
    }
  }
  out
}

#' Multiple imputation by predictive mean matching on a predictor matrix
#'
#' Calls `mice::mice.impute.pmm()` once per imputation; only the marker is
#' missing and the predictors are complete, so this is the univariate step
#' `mice()` runs for this pattern. Predictors that are constant among the
#' observed rows (a resample can lose a rare category), or collinear with
#' the others, are dropped.
#'
#' @param x Marker values, `NA` where missing.
#' @param predictors A numeric matrix, one row per subject.
#' @param n_imp Number of imputations.
#' @param donors Number of donors.
#' @return A `length(x)` x `n_imp` matrix of completed values.
#' @export
ImputePmmMatrix <- function(x, predictors, n_imp, donors = 5L) {
  observed <- !is.na(x)
  completed <- matrix(x, nrow = length(x), ncol = n_imp)
  if (all(observed)) return(completed)
  pred <- FullRankColumns(predictors, observed)
  for (l in seq_len(n_imp)) {
    completed[!observed, l] <- mice::mice.impute.pmm(
      y = x, ry = observed, x = pred, donors = donors)
  }
  completed
}

#' Impose missingness at random on complete data
#'
#' The marker is set missing with probability
#' \eqn{\mathrm{expit}(\alpha_0 + 0.5 D - 0.3 a + 0.2 m)}, with \eqn{a} the
#' standardized age and \eqn{m} the male indicator, so that it depends only
#' on variables in the imputation model; \eqn{\alpha_0} is solved so that the
#' expected fraction is `rate`.
#'
#' @param cohort Complete cases: `smoker`, `age`, `sex`.
#' @param rate Target missing fraction.
#' @return A logical vector, `TRUE` where the marker is set missing.
#' @export
ImposeMissing <- function(cohort, rate) {
  lin <- 0.5 * cohort$smoker - 0.3 * (cohort$age - 50) / 15 +
    0.2 * (cohort$sex == "male")
  a0 <- stats::uniroot(function(a) mean(stats::plogis(a + lin)) - rate,
                       c(-20, 20), tol = 1e-10)$root
  stats::runif(nrow(cohort)) < stats::plogis(a0 + lin)
}

#' Stratum-specific and population-optimal cutoffs from completed data
#'
#' Within one stratum \eqn{v}, the stratum-specific cutoff maximizes
#' \eqn{\bar F_0(c \mid v) - \bar F_1(c \mid v)} and the population-optimal
#' cutoff maximizes \eqn{w_0 \bar F_0(c \mid v) - w_1 \bar F_1(c \mid v)},
#' with \eqn{w_d = P(V = v \mid D = d)} and \eqn{\bar F_d} the distribution
#' functions averaged over the completed datasets; the overall Youden index
#' of a rule with one cutoff per stratum is the sum over strata of the
#' second criterion, so it is maximized stratum by stratum.
#'
#' @param completed An N x L matrix of the stratum's completed values.
#' @param d Disease status in the stratum.
#' @param w0,w1 The stratum's shares of group 0 and group 1.
#' @return A list with `c_cs`, `j_cs` (the stratum's Youden maximum),
#'   `c_pop`.
#' @export
StratumCutoffs <- function(completed, d, w0, w1) {
  completed <- as.matrix(completed)
  u <- sort(unique(as.vector(completed)))
  f0 <- PoolMean(t(apply(completed[d == 0, , drop = FALSE], 2, function(x) {
    findInterval(u, sort(x)) / length(x)
  })))
  f1 <- PoolMean(t(apply(completed[d == 1, , drop = FALSE], 2, function(x) {
    findInterval(u, sort(x)) / length(x)
  })))
  cs <- MaximizeStep(u, f0 - f1)
  pop <- MaximizeStep(u, w0 * f0 - w1 * f1)
  list(c_cs = cs$cutoff, j_cs = cs$value, c_pop = pop$cutoff)
}

#' Compact summary of one application analysis
#'
#' @param res Output of `MiYoudenInference()`.
#' @param reference Optional thresholds (on the analysis scale) to locate
#'   in the comparison-based sets.
#' @return A list: the grid and the curve with every band; the chosen
#'   cutoff, the reported and corrected indices, the optimize-first index
#'   and gap; the sets as logical vectors over the grid with their ranges;
#'   and, for each reference threshold, whether the nearest grid point is in
#'   each set.
#' @export
SummarizeAnalysis <- function(res, reference = numeric(0)) {
  RangeOf <- function(in_set) {
    if (!any(in_set)) return(c(NA_real_, NA_real_))
    range(res$grid[in_set])
  }
  sets <- list(
    comp_boot = res$boot$comp_set, comp_hybrid = res$hybrid$comp_set,
    plug_boot = res$boot$comp_set_plugin,
    plug_hybrid = res$hybrid$comp_set_plugin,
    band_boot = res$boot$band_set, band_hybrid = res$hybrid$band_set)
  ref <- lapply(reference, function(r) {
    k <- which.min(abs(res$grid - r))
    vapply(sets, function(s) s[k], logical(1))
  })
  list(grid = res$grid, estimate = res$estimate,
       boot = res$boot[c("lower", "upper", "q", "q_comp", "q_comp_plugin")],
       hybrid = res$hybrid[c("lower", "upper", "q", "q_comp",
                             "q_comp_plugin")],
       rubin = res$rubin[c("lower", "upper", "q")],
       pointwise = res$pointwise[c("lower", "upper")],
       c_hat = res$c_hat, apparent = res$apparent,
       apparent_at_c_hat = res$apparent_at_c_hat,
       corrected_20 = res$corrected_20, corrected_2 = res$corrected_2,
       optimism_20 = res$optimism_20, optimism_2 = res$optimism_2,
       c_p2 = res$c_p2, gap = res$gap, b_c = res$b_c, c_bag = res$c_bag,
       sets = sets, set_ranges = lapply(sets, RangeOf),
       reference = reference, reference_in_sets = ref)
}

#' Run one analysis of the application
#'
#' Seeds the L'Ecuyer-CMRG generator with the task's seed and applies
#' `MiYoudenInference()`, imputing by predictive mean matching on the
#' task's predictors, or without imputation when nothing is missing.
#'
#' @param task A list with `name`, `seed`, `x` (the marker, `NA` where
#'   missing), `d`, `predictors`, and the procedure's settings `n_imp`,
#'   `n_boot`, `m_boot`, `n_boot_opt`, `n_boot_opt2`, `grid_n`, `n_draw`.
#' @return The output of `MiYoudenInference()`, with `name` and
#'   `seconds`.
#' @export
RunApplicationTask <- function(task) {
  RNGkind("L'Ecuyer-CMRG")
  set.seed(task$seed)
  start <- proc.time()[["elapsed"]]
  x <- task$x
  pred <- task$predictors
  Impute <- function(rows, m) ImputePmmMatrix(x[rows], pred[rows, , drop = FALSE],
                                              m)
  res <- MiYoudenInference(task$d, Impute, n_imp = task$n_imp,
                           n_boot = task$n_boot, m_boot = task$m_boot,
                           n_boot_opt = task$n_boot_opt,
                           n_boot_opt2 = task$n_boot_opt2,
                           grid_n = task$grid_n, n_draw = task$n_draw)
  res$name <- task$name
  res$seconds <- proc.time()[["elapsed"]] - start
  res
}

#' Run the application's analyses on PSOCK workers
#'
#' @param tasks A list of tasks for `RunApplicationTask()`.
#' @param n_workers Number of workers.
#' @param root The project root.
#' @return A list of results, named by the tasks' names.
#' @export
RunApplicationTasks <- function(tasks, n_workers, root = here::here()) {
  cl <- StartWorkers(n_workers, root)
  on.exit(parallel::stopCluster(cl), add = TRUE)
  out <- parallel::parLapplyLB(cl, tasks, RunApplicationTask,
                               chunk.size = 1)
  names(out) <- vapply(tasks, function(t) t$name, character(1))
  out
}
