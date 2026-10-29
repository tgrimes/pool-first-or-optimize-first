# Inference for the pooled Youden curve under multiple imputation: the
# curve on a grid, Rubin's-rules and bootstrap-then-impute sup-t bands, the
# near-optimal set, and the bootstrap optimism correction of the index
# (pilot-b/preregistration.md, section 2).

#' Group distribution functions and Youden curves on a grid
#'
#' @param completed An N x L matrix of completed marker values.
#' @param d Disease status (0 or 1), one per row.
#' @param grid Increasing thresholds.
#' @return A list of L x length(`grid`) matrices: `f0`, `f1`, and
#'   `j = f0 - f1`.
#' @export
GridCurves <- function(completed, d, grid) {
  completed <- as.matrix(completed)
  n0 <- sum(d == 0)
  n1 <- sum(d == 1)
  f0 <- t(apply(completed[d == 0, , drop = FALSE], 2, function(x) {
    findInterval(grid, sort(x)) / n0
  }))
  f1 <- t(apply(completed[d == 1, , drop = FALSE], 2, function(x) {
    findInterval(grid, sort(x)) / n1
  }))
  f0 <- matrix(f0, nrow = ncol(completed))
  f1 <- matrix(f1, nrow = ncol(completed))
  list(f0 = f0, f1 = f1, j = f0 - f1)
}

#' Covariance of an empirical Youden curve at grid points
#'
#' For an empirical distribution function on \eqn{n} subjects and
#' increasing thresholds \eqn{a \le b},
#' \eqn{\mathrm{Cov}\{\hat F(a), \hat F(b)\} = \{F(a) - F(a)F(b)\}/n}. The
#' two groups are independent, so the covariances of \eqn{\hat F_0 - \hat
#' F_1} add. The plug-in version uses the estimated distribution functions.
#'
#' @param f0,f1 Distribution functions of the two groups at the increasing
#'   grid points (vectors).
#' @param n0,n1 Group sizes.
#' @return A K x K covariance matrix.
#' @export
YoudenCurveCov <- function(f0, f1, n0, n1) {
  k <- length(f0)
  lo <- outer(seq_len(k), seq_len(k), pmin)
  (matrix(f0[lo], k) - outer(f0, f0)) / n0 +
    (matrix(f1[lo], k) - outer(f1, f1)) / n1
}

#' Sup-t critical value from a normal law
#'
#' The `level` quantile of \eqn{\max_k |Z_k| / \sqrt{\Sigma_{kk}}} for
#' \eqn{Z \sim N(0, \Sigma)}, by simulation through the eigendecomposition of
#' \eqn{\Sigma} (negative eigenvalues set to zero). Coordinates whose
#' variance is at most `tol` times the largest are left out, as rounding
#' error of a zero variance.
#'
#' @param sigma A K x K covariance matrix.
#' @param level Coverage level.
#' @param n_draw Number of draws.
#' @param tol Relative tolerance; `tol = 0` leaves out only coordinates with
#'   variance at most zero.
#' @return The critical value.
#' @export
SupTCritical <- function(sigma, level = 0.95, n_draw = 5000L, tol = 1e-10) {
  keep <- diag(sigma) > tol * max(diag(sigma), 0)
  if (!any(keep)) return(stats::qnorm(1 - (1 - level) / 2))
  sigma <- sigma[keep, keep, drop = FALSE]
  eig <- eigen(sigma, symmetric = TRUE)
  root <- eig$vectors %*% diag(sqrt(pmax(eig$values, 0)), length(eig$values))
  z <- matrix(stats::rnorm(n_draw * nrow(sigma)), n_draw) %*% t(root)
  z <- abs(z) / rep(sqrt(diag(sigma)), each = n_draw)
  unname(stats::quantile(apply(z, 1, max), level, type = 7))
}

#' Rubin's-rules sup-t band for the pooled Youden curve
#'
#' @param grid_curves Output of `GridCurves()` for the L completed datasets.
#' @param n0,n1 Group sizes.
#' @param level Simultaneous coverage level.
#' @param n_draw Draws for the critical value.
#' @return A list with `estimate`, `se`, `q`, `lower`, `upper` (vectors over
#'   the grid except `q`).
#' @export
RubinBand <- function(grid_curves, n0, n1, level = 0.95, n_draw = 5000L) {
  j <- grid_curves$j
  n_imp <- nrow(j)
  est <- PoolMean(j)
  u_bar <- Reduce(`+`, lapply(seq_len(n_imp), function(l) {
    YoudenCurveCov(grid_curves$f0[l, ], grid_curves$f1[l, ], n0, n1)
  })) / n_imp
  b <- if (n_imp > 1) stats::cov(j) else 0 * u_bar
  t_cov <- u_bar + (1 + 1 / n_imp) * b
  q <- SupTCritical(t_cov, level, n_draw)
  se <- sqrt(pmax(diag(t_cov), 0))
  list(estimate = est, se = se, q = q, lower = est - q * se,
       upper = est + q * se)
}

#' Pointwise Rubin's intervals on a grid, read as a band
#'
#' @param grid_curves Output of `GridCurves()`.
#' @param n0,n1 Group sizes.
#' @param level Pointwise level.
#' @return A list with `lower` and `upper` over the grid.
#' @export
PointwiseRubinBand <- function(grid_curves, n0, n1, level = 0.95) {
  f0 <- grid_curves$f0
  f1 <- grid_curves$f1
  ints <- vapply(seq_len(ncol(f0)), function(k) {
    ri <- RubinInterval(f0[, k] - f1[, k],
                        f0[, k] * (1 - f0[, k]) / n0 +
                          f1[, k] * (1 - f1[, k]) / n1, level)
    c(ri$lower, ri$upper)
  }, numeric(2))
  list(lower = ints[1, ], upper = ints[2, ])
}

#' Bootstrap-then-impute sup-t band
#'
#' Each of \eqn{R_B} resamples is imputed `m` times. With \eqn{\bar J_b} the
#' mean of resample \eqn{b}'s curves, \eqn{V_b} its variance over resamples,
#' and \eqn{s_w^2} the within-resample variance of single imputations, the
#' variance of an \eqn{L}-imputation estimate is
#' \eqn{\max\{V_b - s_w^2/m + s_w^2/L, 0\}}. The critical value is the
#' `level` quantile of \eqn{\max_k |\bar J_b(c_k) - m(c_k)| / \sqrt{V_b(c_k)}}.
#'
#' @param boot_curves A list of `m` matrices, each \eqn{R_B} x K: the grid
#'   curves of imputation 1, 2, ... of every resample.
#' @param estimate The pooled curve of the original data on the grid.
#' @param n_imp Number of imputations \eqn{L} of `estimate`.
#' @param level Simultaneous coverage level.
#' @return A list with `se`, `q`, `lower`, `upper`, and the parts `v_boot`
#'   and `s_within`.
#' @export
BootImputeBand <- function(boot_curves, estimate, n_imp, level = 0.95) {
  m <- length(boot_curves)
  boot_mean <- Reduce(`+`, boot_curves) / m
  v_boot <- apply(boot_mean, 2, stats::var)
  s_within <- if (m > 1) {
    Reduce(`+`, lapply(boot_curves, function(x) (x - boot_mean)^2)) / (m - 1)
  } else {
    0 * boot_mean
  }
  s_within <- colMeans(s_within)
  se <- sqrt(pmax(v_boot - s_within / m + s_within / n_imp, 0))
  keep <- v_boot > 0
  centre <- colMeans(boot_mean)
  dev <- abs(boot_mean[, keep, drop = FALSE] -
               rep(centre[keep], each = nrow(boot_mean))) /
    rep(sqrt(v_boot[keep]), each = nrow(boot_mean))
  q <- if (any(keep)) {
    unname(stats::quantile(apply(dev, 1, max), level, type = 7))
  } else {
    stats::qnorm(1 - (1 - level) / 2)
  }
  list(se = se, q = q, lower = estimate - q * se, upper = estimate + q * se,
       v_boot = v_boot, s_within = s_within)
}

#' Whether a band covers a curve everywhere on the grid
#'
#' @param lower,upper Band limits over the grid.
#' @param truth True curve over the grid.
#' @return Logical.
#' @export
BandCovers <- function(lower, upper, truth) {
  all(lower <= truth & truth <= upper)
}

#' Near-optimal set of thresholds from a band
#'
#' The grid points whose upper limit reaches the largest lower limit. If the
#' band covers the true curve, the set contains the true maximizer.
#'
#' @param grid Increasing grid.
#' @param lower,upper Band limits over the grid.
#' @param c_star Optional true maximizer, to check membership by linear
#'   interpolation of the upper limit.
#' @return A list with `in_set` (logical over the grid), `length` (points in
#'   the set times the grid step), and `contains` (`NA` without `c_star`).
#' @export
NearOptimalSet <- function(grid, lower, upper, c_star = NULL) {
  floor_value <- max(lower)
  in_set <- upper >= floor_value
  step <- if (length(grid) > 1) diff(grid)[1] else 0
  contains <- NA
  if (!is.null(c_star)) {
    contains <- c_star >= min(grid) && c_star <= max(grid) &&
      stats::approx(grid, upper, xout = c_star)$y >= floor_value
  }
  list(in_set = in_set, length = sum(in_set) * step, contains = contains)
}

#' Bootstrap optimism of the chosen cutoff's index
#'
#' For each resample, the resample's pooled curve at its own chosen cutoff
#' minus the original pooled curve at that cutoff. The chosen cutoff is
#' `MaximizeStep()`'s (the mean of the midpoints of tied maximizing
#' intervals), so each curve is read at the cutoff, which need not attain the
#' maximum when tied intervals are apart.
#'
#' @param boot_pooled A list with one element per resample, each a list with
#'   `u` (jump points) and `j_bar` (the resample's pooled step curve).
#' @param u,j_bar The original pooled step curve: jump points and values.
#' @return A vector of optimism estimates, one per resample.
#' @export
BootOptimism <- function(boot_pooled, u, j_bar) {
  vapply(boot_pooled, function(bp) {
    cutoff <- MaximizeStep(bp$u, bp$j_bar)$cutoff
    StepValue(cutoff, bp$u, bp$j_bar) - StepValue(cutoff, u, j_bar)
  }, numeric(1))
}

#' Resample subjects with replacement within each disease group
#'
#' @param d Disease status.
#' @return Row indices of the resample, group sizes kept.
#' @export
ResampleWithinGroups <- function(d) {
  unlist(lapply(split(seq_along(d), d), function(rows) {
    rows[sample.int(length(rows), length(rows), replace = TRUE)]
  }), use.names = FALSE)
}

#' Multiple imputation by Bayesian normal linear regression
#'
#' Calls `mice::mice.impute.norm()` once per imputation with the predictors
#' \eqn{D}, \eqn{Z}, and \eqn{D \times Z}: a draw of the coefficients and the
#' residual variance, then normal draws for the missing values. Collinear
#' predictors are dropped first (`FullRankColumns()`).
#'
#' @param x Marker values, `NA` where missing.
#' @param d Disease status (0 or 1).
#' @param z Auxiliary variable.
#' @param n_imp Number of imputations.
#' @return An N x `n_imp` matrix of completed marker values.
#' @export
ImputeNorm <- function(x, d, z, n_imp) {
  observed <- !is.na(x)
  predictors <- FullRankColumns(cbind(d = d, z = z, dz = d * z), observed)
  completed <- matrix(x, nrow = length(x), ncol = n_imp)
  if (all(observed)) return(completed)
  for (l in seq_len(n_imp)) {
    completed[!observed, l] <- mice::mice.impute.norm(
      y = x, ry = observed, x = predictors)
  }
  completed
}

#' Impute with a named engine
#'
#' @param engine `"none"` (copies of the data, which must be complete),
#'   `"pmm"` (5 donors), `"pmm10"` (10 donors), `"norm"`, or `"nn"`.
#' @param x,d,z Marker (with `NA`), disease status, auxiliary.
#' @param n_imp Number of imputations.
#' @return An N x `n_imp` matrix of completed marker values.
#' @export
ImputeWith <- function(engine, x, d, z, n_imp) {
  switch(engine,
         none = matrix(x, nrow = length(x), ncol = n_imp),
         pmm = ImputePmm(x, d, z, n_imp),
         pmm10 = ImputePmm(x, d, z, n_imp, donors = 10L),
         norm = ImputeNorm(x, d, z, n_imp),
         nn = ImputeNearestNeighbour(x, d, z, n_imp),
         stop("unknown engine: ", engine))
}
