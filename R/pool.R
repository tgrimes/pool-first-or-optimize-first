# The pooling rules across imputations, and Rubin's rules for J(c).
#   P1, pool first: argmax and maximum of the averaged curve.
#   P2, optimize then mean: mean of the per-dataset argmaxes and maxima.
#   P3, optimize then median: median of the argmaxes, averaged curve there.

#' Mean across imputations, exact for identical inputs
#'
#' Computes \eqn{v_1 + L^{-1} \sum_l (v_l - v_1)}, which equals the ordinary
#' mean and returns \eqn{v_1} exactly when every \eqn{v_l} equals it, so
#' that pooling identical curves gives a gap of exactly zero in floating
#' point.
#'
#' @param v A vector (one value per imputation) or an L x m matrix (one row
#'   per imputation, averaged over rows).
#' @return The mean: a scalar for a vector, a length-m vector for a matrix.
#' @export
PoolMean <- function(v) {
  if (is.matrix(v)) {
    first <- v[1, ]
    return(first + colSums(v - rep(first, each = nrow(v))) / nrow(v))
  }
  v[1] + sum(v - v[1]) / length(v)
}

#' Summaries shared by the pooling rules
#'
#' @param c_l Per-dataset cutoffs.
#' @param m_l Per-dataset maxima.
#' @param p1 List with the pool-first `cutoff` and `value`.
#' @param p3_cutoff Median of the per-dataset cutoffs.
#' @param p3_index The averaged curve at the median cutoff.
#' @return A list with the three rules' cutoffs and indices, `b_c`, and the
#'   per-dataset cutoffs and maxima.
#' @keywords internal
CollectRules <- function(c_l, m_l, p1, p3_cutoff, p3_index) {
  c_bar <- PoolMean(c_l)
  list(cutoff = c(p1 = p1$cutoff, p2 = c_bar, p3 = p3_cutoff),
       index = c(p1 = p1$value, p2 = PoolMean(m_l), p3 = p3_index),
       b_c = mean((c_l - c_bar)^2), c_l = c_l, m_l = m_l)
}

#' Pool empirical step curves
#'
#' @param u Sorted jump points shared by all curves.
#' @param values An L x length(`u`) matrix of curve values.
#' @return See `CollectRules()`; also `j_bar`, the averaged curve.
#' @export
PoolStepCurves <- function(u, values) {
  per <- apply(values, 1, function(v) unlist(MaximizeStep(u, v)))
  j_bar <- PoolMean(values)
  p1 <- MaximizeStep(u, j_bar)
  p3_cutoff <- stats::median(per["cutoff", ])
  out <- CollectRules(per["cutoff", ], per["value", ], p1, p3_cutoff,
                      StepValue(p3_cutoff, u, j_bar))
  out$j_bar <- j_bar
  out
}

#' Maximize one smooth curve: a grid search, then `optimize()` between the
#' neighbours of the best grid point
#'
#' @param f Function of a scalar threshold.
#' @param grid Increasing grid.
#' @param grid_values `f` on the grid.
#' @param tol Tolerance of `optimize()`.
#' @return A list with `cutoff` and `value`.
#' @keywords internal
MaximizeSmooth <- function(f, grid, grid_values, tol = 1e-8) {
  k <- which.max(grid_values)
  lo <- grid[max(k - 1, 1)]
  hi <- grid[min(k + 1, length(grid))]
  opt <- stats::optimize(f, c(lo, hi), maximum = TRUE, tol = tol)
  if (opt$objective < grid_values[k]) {
    return(list(cutoff = grid[k], value = grid_values[k]))
  }
  list(cutoff = opt$maximum, value = opt$objective)
}

#' Pool smooth curves
#'
#' @param curve_fun Function `(cutoff, l)` returning the curves with indices
#'   `l` at a scalar threshold.
#' @param n_curves Number of curves \eqn{L}.
#' @param grid Increasing grid for the initial search.
#' @param grid_values Optional L x length(`grid`) matrix of curve values on
#'   the grid.
#' @param tol Tolerance of `optimize()`.
#' @return See `CollectRules()`; also `j_bar_fun`, the averaged curve.
#' @export
PoolSmoothCurves <- function(curve_fun, n_curves, grid, grid_values = NULL,
                             tol = 1e-8) {
  if (is.null(grid_values)) {
    grid_values <- matrix(vapply(grid, curve_fun, numeric(n_curves),
                                 l = seq_len(n_curves)), nrow = n_curves)
  }
  per <- vapply(seq_len(n_curves), function(l) {
    unlist(MaximizeSmooth(function(cc) curve_fun(cc, l), grid,
                          grid_values[l, ], tol))
  }, numeric(2))
  j_bar_fun <- function(cc) PoolMean(curve_fun(cc, seq_len(n_curves)))
  p1 <- MaximizeSmooth(j_bar_fun, grid, PoolMean(grid_values), tol)
  p3_cutoff <- stats::median(per[1, ])
  out <- CollectRules(per[1, ], per[2, ], p1, p3_cutoff,
                      j_bar_fun(p3_cutoff))
  out$j_bar_fun <- j_bar_fun
  out
}

#' Rubin's rules for one scalar estimand
#'
#' \eqn{T = \bar U + (1 + 1/L) B}, with Rubin's degrees of freedom
#' \eqn{\nu = (L - 1)\{1 + \bar U / ((1 + 1/L) B)\}^2}, infinite when
#' \eqn{B = 0}.
#'
#' @param q Per-imputation estimates.
#' @param u Per-imputation variances.
#' @param level Confidence level.
#' @return A list with `estimate`, `se`, `df`, `lower`, `upper`.
#' @export
RubinInterval <- function(q, u, level = 0.95) {
  n_imp <- length(q)
  q_bar <- PoolMean(q)
  u_bar <- mean(u)
  b <- 0
  if (n_imp > 1) b <- stats::var(q)
  t_var <- u_bar + (1 + 1 / n_imp) * b
  df <- Inf
  if (b > 0) df <- (n_imp - 1) * (1 + u_bar / ((1 + 1 / n_imp) * b))^2
  half <- stats::qt(1 - (1 - level) / 2, df) * sqrt(t_var)
  list(estimate = q_bar, se = sqrt(t_var), df = df,
       lower = q_bar - half, upper = q_bar + half)
}
