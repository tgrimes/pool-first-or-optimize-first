# Within-dataset Youden curves: the empirical step curve and the Gaussian
# kernel curve. A subject is called positive when X > c, so
# J(c) = F0(c) - F1(c).

#' Empirical Youden curves of several completed datasets
#'
#' Evaluates each completed dataset's empirical Youden curve at the sorted
#' distinct values `u` of all completed datasets. The curve is constant on
#' each interval \eqn{[u_k, u_{k+1})}, so these values describe it fully.
#'
#' @param completed An N x L matrix of completed marker values.
#' @param d Disease status (0 or 1), one per row.
#' @return A list with `u` (the sorted distinct values) and `values`, an
#'   L x length(`u`) matrix of \eqn{\hat J_l(u_k)}.
#' @export
EmpiricalCurves <- function(completed, d) {
  completed <- as.matrix(completed)
  u <- sort(unique(as.vector(completed)))
  n0 <- sum(d == 0)
  n1 <- sum(d == 1)
  values <- t(apply(completed, 2, function(x) {
    findInterval(u, sort(x[d == 0])) / n0 -
      findInterval(u, sort(x[d == 1])) / n1
  }))
  list(u = u, values = matrix(values, nrow = ncol(completed)))
}

#' Maximizer of a step curve
#'
#' The curve takes `v[k]` on \eqn{[u_k, u_{k+1})}. Every interval whose value
#' is within `tol` of the maximum is a maximizer; the cutoff is the mean of
#' their midpoints, a symmetric rule.
#'
#' @param u Sorted jump points.
#' @param v Curve values on the intervals that start at `u`.
#' @param tol Tolerance for ties at the maximum.
#' @return A list with `cutoff` and `value` (the maximum).
#' @export
MaximizeStep <- function(u, v, tol = 1e-12) {
  top <- max(v)
  k <- which(v >= top - tol)
  mid <- (u + c(u[-1], u[length(u)])) / 2
  list(cutoff = mean(mid[k]), value = top)
}

#' Value of a step curve at given thresholds
#'
#' @param cutoff Thresholds.
#' @param u Sorted jump points.
#' @param v Curve values on the intervals that start at `u` (0 below
#'   `u[1]`).
#' @return The curve's values at `cutoff`.
#' @export
StepValue <- function(cutoff, u, v) {
  k <- findInterval(cutoff, u)
  out <- numeric(length(cutoff))
  out[k > 0] <- v[k[k > 0]]
  out
}

#' Gaussian-kernel estimate of a distribution function
#'
#' \eqn{\hat F(c) = n^{-1} \sum_i \Phi\{(c - X_i)/h\}}.
#'
#' @param cutoff Thresholds.
#' @param x Sample.
#' @param h Bandwidth.
#' @return \eqn{\hat F} at each threshold.
#' @export
KernelCdf <- function(cutoff, x, h) {
  rowMeans(stats::pnorm(outer(cutoff, x, "-") / h))
}

#' Gaussian-kernel Youden curves of several completed datasets
#'
#' Each completed dataset gets its own Silverman bandwidth in each group
#' (`stats::bw.nrd0()`).
#'
#' @param completed An N x L matrix of completed marker values.
#' @param d Disease status (0 or 1), one per row.
#' @return A list with `h0`, `h1` (bandwidths, one per dataset) and
#'   `curve_fun(cutoff, l)`, which returns \eqn{\hat J_l} at the scalar
#'   threshold `cutoff` for each dataset index in `l`.
#' @export
KernelCurves <- function(completed, d) {
  completed <- as.matrix(completed)
  x0 <- completed[d == 0, , drop = FALSE]
  x1 <- completed[d == 1, , drop = FALSE]
  h0 <- apply(x0, 2, stats::bw.nrd0)
  h1 <- apply(x1, 2, stats::bw.nrd0)
  curve_fun <- function(cutoff, l) {
    vapply(l, function(j) {
      mean(stats::pnorm((cutoff - x0[, j]) / h0[j])) -
        mean(stats::pnorm((cutoff - x1[, j]) / h1[j]))
    }, numeric(1))
  }
  grid_fun <- function(grid) {
    t(vapply(seq_len(ncol(completed)), function(j) {
      KernelCdf(grid, x0[, j], h0[j]) - KernelCdf(grid, x1[, j], h1[j])
    }, numeric(length(grid))))
  }
  list(h0 = h0, h1 = h1, curve_fun = curve_fun, grid_fun = grid_fun)
}

#' Group distribution functions at one threshold, per completed dataset
#'
#' @param cutoff A scalar threshold.
#' @param completed An N x L matrix of completed marker values.
#' @param d Disease status.
#' @param estimator `"empirical"` or `"kernel"`.
#' @param h0,h1 Bandwidths per dataset (kernel only).
#' @return An L x 2 matrix with columns `f0` and `f1`.
#' @export
GroupCdfAt <- function(cutoff, completed, d, estimator, h0 = NULL,
                       h1 = NULL) {
  completed <- as.matrix(completed)
  x0 <- completed[d == 0, , drop = FALSE]
  x1 <- completed[d == 1, , drop = FALSE]
  if (estimator == "empirical") {
    f0 <- colMeans(x0 <= cutoff)
    f1 <- colMeans(x1 <= cutoff)
  } else {
    f0 <- colMeans(stats::pnorm((cutoff - x0) / rep(h0, each = nrow(x0))))
    f1 <- colMeans(stats::pnorm((cutoff - x1) / rep(h1, each = nrow(x1))))
  }
  cbind(f0 = f0, f1 = f1)
}
