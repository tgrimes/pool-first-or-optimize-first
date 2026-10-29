# Pilot-c's additions (pilot-c/preregistration.md, section 2): the grid
# from completed values, the covariance split, the hybrid band, and the
# comparison-based near-optimal set.

#' Grid of thresholds from the completed values
#'
#' @param completed An N x L matrix of completed marker values.
#' @param grid_n Number of grid points.
#' @param probs The two quantiles of all completed values that bound the
#'   grid.
#' @return An increasing grid.
#' @export
GridFromCompleted <- function(completed, grid_n = 41L, probs = c(0.1, 0.9)) {
  q <- stats::quantile(as.vector(completed), probs)
  seq(q[1], q[2], length.out = grid_n)
}

#' Covariance of an L-imputation pooled curve from bootstrap-then-impute
#'
#' With \eqn{\bar J_b} the mean of the `m` imputations of resample \eqn{b},
#' \eqn{V} their covariance over resamples, and \eqn{W} the mean
#' within-resample covariance of single imputations, the covariance of an
#' \eqn{L}-imputation estimate is \eqn{V - W/m + W/L}, with negative
#' eigenvalues set to zero.
#'
#' @param boot_curves A list of `m` matrices, each \eqn{R_B} x K.
#' @param n_imp Number of imputations \eqn{L} of the estimate.
#' @return A list with `sigma`, `v`, `w`, and `boot_mean` (the
#'   \eqn{R_B} x K matrix of resample means).
#' @export
CovarianceSplit <- function(boot_curves, n_imp) {
  m <- length(boot_curves)
  boot_mean <- Reduce(`+`, boot_curves) / m
  v <- stats::cov(boot_mean)
  w <- 0 * v
  if (m > 1) {
    for (x in boot_curves) {
      dev <- x - boot_mean
      w <- w + crossprod(dev) / nrow(dev)
    }
    w <- w / (m - 1)
  }
  sigma <- v - w / m + w / n_imp
  eig <- eigen(sigma, symmetric = TRUE)
  sigma <- eig$vectors %*% (pmax(eig$values, 0) * t(eig$vectors))
  list(sigma = sigma, v = v, w = w, boot_mean = boot_mean)
}

#' Draws from a centred normal law
#'
#' @param sigma A K x K covariance matrix.
#' @param n_draw Number of draws.
#' @return An `n_draw` x K matrix.
#' @keywords internal
NormalDraws <- function(sigma, n_draw) {
  eig <- eigen(sigma, symmetric = TRUE)
  root <- eig$vectors %*% diag(sqrt(pmax(eig$values, 0)), nrow(sigma))
  matrix(stats::rnorm(n_draw * nrow(sigma)), n_draw) %*% t(root)
}

#' Standard errors of the differences from one grid point
#'
#' \eqn{s_{jk} = (\Sigma_{jj} + \Sigma_{kk} - 2\Sigma_{jk})^{1/2}} for every
#' \eqn{j}, with a variance below `tol` times the largest diagonal entry set
#' to zero. Grid points with no completed value between them carry identical
#' curves, so their difference has variance zero; after the eigenvalue
#' clipping of `CovarianceSplit()` it is a rounding error instead, about
#' \eqn{10^{-16}} of the diagonal, and a ratio of two rounding errors would
#' enter the comparisons (issue C1 of the background report).
#'
#' @param cov_scale A K x K covariance matrix.
#' @param k The grid point.
#' @param tol Relative tolerance; `tol = 0` sets only negative variances to
#'   zero.
#' @return A vector of K standard errors, zero at `k`.
#' @keywords internal
PairSe <- function(cov_scale, k, tol = 1e-10) {
  d <- diag(cov_scale)
  s2 <- d + d[k] - 2 * cov_scale[, k]
  s2[s2 < tol * max(d, 0)] <- 0
  sqrt(s2)
}

#' Per-point quantiles of the one-sided comparisons
#'
#' For each grid point \eqn{k}, the `level` quantile over draws of
#' \eqn{\max_{j \ne k} (D_j - D_k)/s_{jk}}. Pairs with \eqn{s_{jk} = 0},
#' after the tolerance of `PairSe()`, are left out; a point with no pair left
#' gets `-Inf`.
#'
#' @param draws A matrix of centred draws, one row per draw (bootstrap
#'   deviations or normal draws).
#' @param cov_scale The K x K covariance whose pairwise difference variances
#'   standardize the draws.
#' @param level Coverage level.
#' @param tol Relative tolerance of `PairSe()`.
#' @return A vector of K quantiles.
#' @export
ComparisonQuantiles <- function(draws, cov_scale, level = 0.95,
                                tol = 1e-10) {
  k_n <- ncol(draws)
  vapply(seq_len(k_n), function(k) {
    s <- PairSe(cov_scale, k, tol)
    keep <- s > 0 & seq_len(k_n) != k
    if (!any(keep)) return(-Inf)
    z <- (draws[, keep, drop = FALSE] - draws[, k]) /
      rep(s[keep], each = nrow(draws))
    unname(stats::quantile(apply(z, 1, max), level, type = 7))
  }, numeric(1))
}

#' Critical value of the comparison-based set
#'
#' The largest over grid points of `ComparisonQuantiles()`, so that the
#' comparisons involving whichever point is best hold at the level.
#'
#' @inheritParams ComparisonQuantiles
#' @return The critical value.
#' @export
ComparisonCritical <- function(draws, cov_scale, level = 0.95,
                               tol = 1e-10) {
  max(ComparisonQuantiles(draws, cov_scale, level, tol))
}

#' Comparison-based near-optimal set
#'
#' A grid threshold stays in the set unless some other threshold's pooled
#' curve exceeds it by more than `q` standard errors of their difference.
#' A difference with zero standard error, after the tolerance of `PairSe()`,
#' excludes the point if it is positive.
#'
#' @param estimate The pooled curve on the grid.
#' @param sigma Its K x K covariance.
#' @param q Critical value from `ComparisonCritical()`.
#' @param tol Relative tolerance of `PairSe()`.
#' @return Logical over the grid.
#' @export
ComparisonSet <- function(estimate, sigma, q, tol = 1e-10) {
  k_n <- length(estimate)
  vapply(seq_len(k_n), function(k) {
    s <- PairSe(sigma, k, tol)
    gap <- estimate - estimate[k]
    all(gap[-k] <= q * s[-k])
  }, logical(1))
}

#' Length of a set on the grid and whether it holds a given point
#'
#' @param grid Increasing grid.
#' @param in_set Logical over the grid.
#' @param k_best Index of the target grid point.
#' @return A list with `length` (points in the set times the grid step) and
#'   `contains`.
#' @export
SetOnGrid <- function(grid, in_set, k_best) {
  step <- if (length(grid) > 1) diff(grid)[1] else 0
  list(length = sum(in_set) * step, contains = in_set[k_best])
}

#' Length of the true near-optimal region
#'
#' The length of \eqn{\{c : J(c) \ge J^* - \epsilon\}} for the binormal
#' Youden curve, from its two crossing points.
#'
#' @param delta,sigma1 The shape.
#' @param tol The tolerance \eqn{\epsilon}.
#' @return The length.
#' @export
TrueNearRegionLength <- function(delta, sigma1, tol = 0.01) {
  truth <- MarkerTruth(delta, sigma1)
  f <- function(cc) TrueYouden(cc, delta, sigma1) - (truth$j_star - tol)
  lo <- stats::uniroot(f, c(truth$c_star - 10, truth$c_star),
                       tol = 1e-12)$root
  hi <- stats::uniroot(f, c(truth$c_star, truth$c_star + 10),
                       tol = 1e-12)$root
  hi - lo
}
