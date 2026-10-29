# Known-answer checks of pilot-c's code (pilot-c/preregistration.md,
# section 4). tests/testthat/test-known-answers-c.R asserts them;
# pilot-c/pilot.R saves the table for the report.

#' Run pilot-c's known-answer checks
#'
#' @param seed Seed for the random parts.
#' @return A data frame, one row per check (see `KnownRow()`).
#' @export
KnownAnswerChecksC <- function(seed = 20261030L) {
  set.seed(seed)
  rows <- list()

  # Two independent coordinates: one one-sided comparison per point.
  z2 <- matrix(stats::rnorm(200000 * 2), ncol = 2)
  rows[[1]] <- KnownRow("Comparison critical value",
                        "two independent coordinates, 200,000 draws",
                        "qnorm(0.95)", stats::qnorm(0.95),
                        ComparisonCritical(z2, diag(2)), 0.02, "tol")

  # The hybrid band's critical value for 41 independent coordinates.
  rows[[2]] <- KnownRow("Hybrid band critical value",
                        "41 independent coordinates, 100,000 draws",
                        "qnorm((1 + 0.95^(1/41)) / 2)",
                        stats::qnorm((1 + 0.95^(1 / 41)) / 2),
                        SupTCritical(diag(41), n_draw = 100000L), 0.02,
                        "tol")

  # Covariance split: resample effects with covariance S_s and imputation
  # noise with covariance S_w; the target is S_s + S_w / 20.
  n_boot <- 20000
  s_s <- matrix(c(4, 2, 2, 3), 2) * 1e-4
  s_w <- matrix(c(9, -3, -3, 6), 2) * 1e-4
  a_b <- NormalDraws(s_s, n_boot)
  curves <- lapply(1:2, function(m) a_b + NormalDraws(s_w, n_boot))
  split <- CovarianceSplit(curves, 20)
  target <- s_s + s_w / 20
  rows[[3]] <- KnownRow("Covariance split, diagonal",
                        "synthetic resamples, M = 2, L = 20",
                        "4e-4 + 9e-4 / 20", target[1, 1], split$sigma[1, 1],
                        2e-05, "tol")
  rows[[4]] <- KnownRow("Covariance split, off-diagonal",
                        "synthetic resamples, M = 2, L = 20",
                        "2e-4 - 3e-4 / 20", target[1, 2], split$sigma[1, 2],
                        2e-05, "tol")

  # A comparison-based set built on the true curve holds the best point.
  grid <- seq(-1, 3, length.out = 41)
  j_true <- TrueYouden(grid, 2, 1)
  set <- ComparisonSet(j_true, diag(41) * 1e-4, 2)
  rows[[5]] <- KnownRow("Comparison-based set", "built on the true curve",
                        "contains the best grid point", 1,
                        as.numeric(set[which.max(j_true)]), 0, "tol")

  # A reproducing bootstrap with 20 imputations per resample: optimism 0.
  dat <- SimulateMarkerData(100, 2, 1)
  copies <- matrix(dat$x_full, nrow = nrow(dat), ncol = 20)
  emp <- EmpiricalCurves(copies, dat$d)
  same <- list(u = emp$u, j_bar = PoolMean(emp$values))
  rows[[6]] <- KnownRow("Optimism of a reproducing bootstrap",
                        "20 identical completed datasets per resample",
                        "exactly 0", 0,
                        max(abs(BootOptimism(list(same, same), emp$u,
                                             same$j_bar))), 0, "tol")

  # The true near-optimal region against a separate computation: for the
  # sharp shape the region is symmetric about c* = 1.
  target_j <- 2 * stats::pnorm(1) - 1 - 0.01
  half <- stats::uniroot(function(h) {
    stats::pnorm(1 + h) - stats::pnorm(h - 1) - target_j
  }, c(0, 3), tol = 1e-12)$root
  rows[[7]] <- KnownRow("True near-optimal region",
                        "sharp shape, within 0.01 of J*",
                        "twice the symmetric half-width", 2 * half,
                        TrueNearRegionLength(2, 1), 1e-8, "tol")
  do.call(rbind, rows)
}
