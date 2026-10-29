# Known-answer checks of the re-pilot's code (pilot-b/preregistration.md,
# section 4). tests/testthat/test-known-answers-b.R asserts them;
# pilot-b/pilot.R saves the table for the report.

#' Run the re-pilot's known-answer checks
#'
#' @param seed Seed for the random parts.
#' @return A data frame, one row per check (see `KnownRow()`).
#' @export
KnownAnswerChecksB <- function(seed = 20261029L) {
  set.seed(seed)
  rows <- list()

  # Covariance of an empirical distribution function at a <= b.
  a <- -0.5
  b <- 0.5
  n <- 100
  draws <- t(vapply(seq_len(4000), function(i) {
    x <- stats::rnorm(n)
    c(mean(x <= a), mean(x <= b))
  }, numeric(2)))
  cov_hat <- stats::cov(draws[, 1], draws[, 2])
  cov_true <- (stats::pnorm(a) - stats::pnorm(a) * stats::pnorm(b)) / n
  prod_dev <- (draws[, 1] - mean(draws[, 1])) * (draws[, 2] - mean(draws[, 2]))
  rows[[1]] <- KnownRow("Covariance of an empirical distribution function",
                        "N(0, 1), n = 100, a = -0.5, b = 0.5, 4,000 samples",
                        "(F(a) - F(a) F(b)) / n", cov_true, cov_hat,
                        McseMean(prod_dev), "mcse")
  rows[[2]] <- KnownRow("Covariance formula in code",
                        "YoudenCurveCov() with F1 = 0", "(F(a) - F(a) F(b)) / n",
                        cov_true,
                        YoudenCurveCov(stats::pnorm(c(a, b)), c(0, 0), n,
                                       1)[1, 2], 1e-15, "tol")

  # Sup-t critical values for independent coordinates.
  k <- 41
  q41 <- SupTCritical(diag(k), n_draw = 100000L)
  rows[[3]] <- KnownRow("Sup-t critical value", "41 independent coordinates",
                        "qnorm((1 + 0.95^(1/41)) / 2)",
                        stats::qnorm((1 + 0.95^(1 / k)) / 2), q41, 0.02,
                        "tol")
  q1 <- SupTCritical(matrix(1), n_draw = 100000L)
  rows[[4]] <- KnownRow("Sup-t critical value", "one coordinate",
                        "1.96", stats::qnorm(0.975), q1, 0.02, "tol")

  # Variance split on synthetic resamples: J_bm = a_b + e_bm, with
  # Var(a) = 0.0004 and Var(e) = 0.0009; the target for L = 20 is
  # 0.0004 + 0.0009 / 20.
  n_boot <- 20000
  a_b <- stats::rnorm(n_boot, 0, 0.02)
  curves <- lapply(1:2, function(m) {
    matrix(a_b + stats::rnorm(n_boot, 0, 0.03), ncol = 1)
  })
  split <- BootImputeBand(curves, 0, 20)
  rows[[5]] <- KnownRow("Variance split", "synthetic resamples, M = 2",
                        "0.0004 + 0.0009 / 20", 0.0004 + 0.0009 / 20,
                        split$se^2, 2e-05, "tol")

  # A bootstrap whose resamples reproduce the original curve: optimism 0.
  dat <- SimulateMarkerData(100, 2, 1)
  emp <- EmpiricalCurves(matrix(dat$x_full), dat$d)
  same <- list(u = emp$u, j_bar = emp$values[1, ])
  rows[[6]] <- KnownRow("Optimism of a reproducing bootstrap",
                        "every resample equal to the data", "exactly 0", 0,
                        max(abs(BootOptimism(list(same, same), emp$u,
                                             emp$values[1, ]))), 0, "tol")

  # The near-optimal set of a band that covers the true curve contains c*.
  grid <- seq(-1, 3, length.out = 41)
  j_true <- TrueYouden(grid, 2, 1)
  set <- NearOptimalSet(grid, j_true - 0.01, j_true + 0.01, 1)
  rows[[7]] <- KnownRow("Near-optimal set", "a band of half-width 0.01 around J",
                        "contains c* = 1", 1, as.numeric(set$contains), 0,
                        "tol")

  # Normal imputation under the correct model: in group 0, X | Z is normal
  # with mean Z / 2 and variance 1 / 2.
  big <- SimulateMarkerData(20000, 2, 1, MissingIntercept(0.4, 2, 1))
  imp <- ImputeNorm(big$x, big$d, big$z, 1)[, 1]
  miss0 <- !big$observed & big$d == 0
  resid <- imp[miss0] - big$z[miss0] / 2
  rows[[8]] <- KnownRow("Normal imputation, conditional mean",
                        "group 0, 20,000 per group, 40% missing",
                        "imputed minus Z / 2 averages 0", 0, mean(resid),
                        McseMean(resid), "mcse")
  rows[[9]] <- KnownRow("Normal imputation, conditional variance",
                        "group 0, 20,000 per group, 40% missing",
                        "variance of imputed minus Z / 2 is 0.5", 0.5,
                        stats::var(resid),
                        sqrt(2 / (length(resid) - 1)) * 0.5, "mcse")
  do.call(rbind, rows)
}
