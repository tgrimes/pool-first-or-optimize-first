# The pilot's design table and the code that runs one replicate and one
# data cell. pilot/pilot.R calls these.

#' The pilot's design table
#'
#' One row per data cell (shape, missing fraction, size, engine, number of
#' imputations); both estimators are applied to every data cell. Cells are
#' numbered in a fixed order, and cell `k` is seeded with `base_seed + k`.
#'
#' @param base_seed Seed offset.
#' @return A data frame with `cell`, `shape`, `delta`, `sigma1`,
#'   `miss_rate`, `alpha0`, `n`, `engine`, `n_imp`, `seed`, `base`.
#' @export
PilotDesign <- function(base_seed = 20261028L) {
  shapes <- data.frame(shape = c("sharp", "flat"), delta = c(2, 1.5),
                       sigma1 = c(1, 2.5))
  main <- expand.grid(miss_rate = c(0, 0.4, 0.6), n = c(250L, 1000L),
                      engine = c("pmm", "nn"), shape = shapes$shape,
                      stringsAsFactors = FALSE)
  main$engine[main$miss_rate == 0] <- "none"
  main <- unique(main)
  main$n_imp <- 20L
  extra <- data.frame(miss_rate = 0.4, n = 250L, engine = "pmm",
                      shape = "sharp", n_imp = c(5L, 100L))
  design <- rbind(main, extra)
  design <- merge(design, shapes, by = "shape", sort = FALSE)
  design <- design[order(match(design$shape, shapes$shape), design$n_imp != 20,
                         design$n_imp, design$engine != "none",
                         design$engine != "pmm", design$n,
                         design$miss_rate), ]
  design$alpha0 <- NA_real_
  for (i in which(design$miss_rate > 0)) {
    design$alpha0[i] <- MissingIntercept(design$miss_rate[i],
                                         design$delta[i], design$sigma1[i])
  }
  design$cell <- seq_len(nrow(design))
  design$seed <- base_seed + design$cell
  design$base <- design$shape == "sharp" & design$miss_rate == 0.4 &
    design$n == 250 & design$engine == "pmm" & design$n_imp == 20
  rownames(design) <- NULL
  design[, c("cell", "shape", "delta", "sigma1", "miss_rate", "alpha0", "n",
             "engine", "n_imp", "seed", "base")]
}

#' Analyse one set of completed datasets with one estimator
#'
#' @param completed An N x L matrix of completed marker values.
#' @param d Disease status.
#' @param observed Logical, the marker was observed (rows equal in every
#'   completed dataset).
#' @param estimator `"empirical"` or `"kernel"`.
#' @param truth Output of `MarkerTruth()`.
#' @param grid_n Number of grid points for the kernel search.
#' @return A one-row data frame of per-replicate quantities.
#' @export
AnalyseCompleted <- function(completed, d, observed, estimator, truth,
                             grid_n = 201L) {
  n_imp <- ncol(completed)
  n <- sum(d == 0)
  h0 <- h1 <- NULL
  kappa_hat <- NA_real_
  if (estimator == "empirical") {
    curves <- EmpiricalCurves(completed, d)
    pooled <- PoolStepCurves(curves$u, curves$values)
  } else {
    kc <- KernelCurves(completed, d)
    h0 <- kc$h0
    h1 <- kc$h1
    observed_x <- completed[observed, 1]
    grid <- seq(stats::quantile(observed_x, 0.005),
                stats::quantile(observed_x, 0.995), length.out = grid_n)
    pooled <- PoolSmoothCurves(kc$curve_fun, n_imp, grid,
                               kc$grid_fun(grid))
    step <- 0.02
    c1 <- pooled$cutoff[["p1"]]
    kappa_hat <- -(pooled$j_bar_fun(c1 + step) - 2 * pooled$index[["p1"]] +
                     pooled$j_bar_fun(c1 - step)) / step^2
  }
  at <- truth$c_star + c(mid = 0, lo = -0.5, hi = 0.5)
  cover <- vapply(at, function(cc) {
    f <- GroupCdfAt(cc, completed, d, estimator, h0, h1)
    ri <- RubinInterval(f[, "f0"] - f[, "f1"],
                        f[, "f0"] * (1 - f[, "f0"]) / n +
                          f[, "f1"] * (1 - f[, "f1"]) / n)
    j_true <- TrueYouden(cc, truth$delta, truth$sigma1)
    c(ri$lower <= j_true && j_true <= ri$upper, ri$upper - ri$lower)
  }, numeric(2))
  true_j <- TrueYouden(pooled$cutoff, truth$delta, truth$sigma1)
  data.frame(
    estimator = estimator,
    c_p1 = pooled$cutoff[["p1"]], c_p2 = pooled$cutoff[["p2"]],
    c_p3 = pooled$cutoff[["p3"]],
    j_p1 = pooled$index[["p1"]], j_p2 = pooled$index[["p2"]],
    j_p3 = pooled$index[["p3"]],
    tj_p1 = true_j[1], tj_p2 = true_j[2], tj_p3 = true_j[3],
    gap = pooled$index[["p2"]] - pooled$index[["p1"]],
    b_c = pooled$b_c,
    pred_gap = truth$kappa * pooled$b_c / 2,
    pred_cdiff = truth$tau * pooled$b_c / (2 * truth$kappa),
    pred_gap_hat = kappa_hat * pooled$b_c / 2,
    cover_mid = cover[1, "mid"], cover_lo = cover[1, "lo"],
    cover_hi = cover[1, "hi"], width_mid = cover[2, "mid"],
    stringsAsFactors = FALSE)
}

#' Run one replicate of one data cell
#'
#' Simulates a dataset, imputes it (or copies the full data `n_imp` times
#' when nothing is missing), and analyses the completed datasets with both
#' estimators.
#'
#' @param cell One row of `PilotDesign()`.
#' @param truth Output of `MarkerTruth()` for the cell's shape.
#' @param estimators Estimators to apply.
#' @return A data frame with one row per estimator.
#' @export
RunReplicate <- function(cell, truth,
                         estimators = c("empirical", "kernel")) {
  dat <- SimulateMarkerData(cell$n, cell$delta, cell$sigma1, cell$alpha0)
  if (cell$engine == "none") {
    completed <- matrix(dat$x_full, nrow = nrow(dat), ncol = cell$n_imp)
  } else if (cell$engine == "pmm") {
    completed <- ImputePmm(dat$x, dat$d, dat$z, cell$n_imp)
  } else {
    completed <- ImputeNearestNeighbour(dat$x, dat$d, dat$z, cell$n_imp)
  }
  out <- do.call(rbind, lapply(estimators, function(est) {
    AnalyseCompleted(completed, dat$d, dat$observed, est, truth)
  }))
  out$miss_frac <- mean(!dat$observed)
  out
}

#' Run every replicate of one data cell
#'
#' Seeds the L'Ecuyer-CMRG generator with the cell's own seed, so the
#' result does not depend on the worker that runs it.
#'
#' @param cell One row of `PilotDesign()` or `PilotDesignB()`.
#' @param n_rep Number of replicates.
#' @param replicate_fun The function that runs one replicate,
#'   `RunReplicate()` for the first pilot, `RunReplicateB()` for the
#'   re-pilot.
#' @return A data frame with one row per replicate (and estimator, for the
#'   first pilot), with the cell number, the replicate number, and the
#'   elapsed seconds.
#' @export
RunDataCell <- function(cell, n_rep, replicate_fun = RunReplicate) {
  RNGkind("L'Ecuyer-CMRG")
  set.seed(cell$seed)
  truth <- MarkerTruth(cell$delta, cell$sigma1)
  start <- proc.time()[["elapsed"]]
  reps <- lapply(seq_len(n_rep), function(r) {
    out <- replicate_fun(cell, truth)
    out$rep <- r
    out
  })
  out <- do.call(rbind, reps)
  out$cell <- cell$cell
  attr(out, "seconds") <- proc.time()[["elapsed"]] - start
  out
}
