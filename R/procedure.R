# The proposed procedure applied to one dataset with a marker missing for
# some subjects: the pooled empirical Youden curve, its bands, the
# near-optimal sets, and the optimism-corrected index. The simulation's
# replicate (RunReplicateC()) and the application both call it.

#' Inference for the pooled Youden curve of a multiply imputed marker
#'
#' Imputes the data `n_imp` times and pools the empirical Youden curves.
#' On a grid of `grid_n` thresholds between the 10% and 90% quantiles of
#' the completed values it builds the pointwise Rubin's intervals, the
#' Rubin's-rules sup-t band, and the bootstrap and hybrid bands from
#' `n_boot` resamples within disease groups, each imputed `m_boot` times;
#' the band-based and comparison-based near-optimal sets of each
#' construction, the latter with the largest per-point critical value and
#' with the one at the estimated best grid point; and the optimism
#' correction of the reported index from `n_boot_opt` resamples imputed
#' `n_imp` times (and, secondarily, from the first `n_boot_opt2` curve
#' resamples with `m_boot` imputations).
#'
#' @param d Disease status (0 or 1).
#' @param impute A function `(rows, m)` returning a `length(rows)` x `m`
#'   matrix of completed marker values for the subjects `rows` (with
#'   repeats, for a resample), imputed from those subjects alone.
#' @param n_imp Imputations of the analysis, \eqn{L}.
#' @param n_boot,m_boot Resamples for the curve and imputations of each.
#' @param n_boot_opt Resamples for the matched optimism correction.
#' @param n_boot_opt2 Curve resamples reused for the `m_boot`-imputation
#'   correction.
#' @param grid_n Grid points.
#' @param n_draw Normal draws for the Rubin's-rules and hybrid critical
#'   values.
#' @return A list: `grid`; `estimate` (the pooled curve on the grid);
#'   `completed` (the analysis's completed datasets); `u`
#'   and `j_bar` (the pooled step curve); `c_hat`, `apparent` (its
#'   maximum), `apparent_at_c_hat` (the curve at the chosen cutoff);
#'   `c_p2` and `gap` (optimize first: the mean cutoff and the mean maximum
#'   minus `apparent`), `b_c` (the between-imputation variance of the
#'   cutoffs); `optimism_20`, `optimism_2`, `corrected_20`, `corrected_2`;
#'   `c_bag` (the mean cutoff of the matched resamples); `pointwise`,
#'   `rubin` (lists with `lower`, `upper`, `se`, `q`); `se` (from the split
#'   covariance); for `boot` and `hybrid`, lists with `lower`, `upper`,
#'   `q`, `q_comp`, `q_comp_plugin`, `band_set`, `comp_set`, and
#'   `comp_set_plugin` (logical over the grid).
#' @export
MiYoudenInference <- function(d, impute, n_imp = 20L, n_boot = 1000L,
                              m_boot = 2L, n_boot_opt = 100L,
                              n_boot_opt2 = 200L, grid_n = 41L,
                              n_draw = 5000L) {
  n0 <- sum(d == 0)
  n1 <- sum(d == 1)
  completed <- impute(seq_along(d), n_imp)
  emp <- EmpiricalCurves(completed, d)
  pooled <- PoolStepCurves(emp$u, emp$values)
  c_hat <- pooled$cutoff[["p1"]]
  at_c_hat <- StepValue(c_hat, emp$u, pooled$j_bar)

  grid <- GridFromCompleted(completed, grid_n)
  gc <- GridCurves(completed, d, grid)
  estimate <- PoolMean(gc$j)
  pw <- PointwiseRubinBand(gc, n0, n1)
  rb <- RubinBand(gc, n0, n1, n_draw = n_draw)

  # Resamples for the curve; the first n_boot_opt2 also give the
  # m_boot-imputation optimism.
  boot_grid <- replicate(m_boot, matrix(NA_real_, n_boot, grid_n),
                         simplify = FALSE)
  pooled_2 <- vector("list", n_boot_opt2)
  for (b in seq_len(n_boot)) {
    idx <- ResampleWithinGroups(d)
    comp_b <- impute(idx, m_boot)
    gb <- GridCurves(comp_b, d[idx], grid)
    for (m in seq_len(m_boot)) boot_grid[[m]][b, ] <- gb$j[m, ]
    if (b <= n_boot_opt2) {
      emp_b <- EmpiricalCurves(comp_b, d[idx])
      pooled_2[[b]] <- list(u = emp_b$u, j_bar = PoolMean(emp_b$values))
    }
  }
  # Resamples for the matched correction, imputed as the analysis is.
  pooled_20 <- lapply(seq_len(n_boot_opt), function(b) {
    idx <- ResampleWithinGroups(d)
    comp_b <- impute(idx, n_imp)
    emp_b <- EmpiricalCurves(comp_b, d[idx])
    list(u = emp_b$u, j_bar = PoolMean(emp_b$values))
  })
  opt_20 <- BootOptimism(pooled_20, emp$u, pooled$j_bar)
  opt_2 <- BootOptimism(pooled_2, emp$u, pooled$j_bar)
  c_bag <- mean(vapply(pooled_20, function(bp) {
    MaximizeStep(bp$u, bp$j_bar)$cutoff
  }, numeric(1)))

  cs <- CovarianceSplit(boot_grid, n_imp)
  se <- sqrt(diag(cs$sigma))
  centred <- cs$boot_mean - rep(colMeans(cs$boot_mean),
                                each = nrow(cs$boot_mean))
  keep <- diag(cs$v) > 0
  q_boot <- unname(stats::quantile(
    apply(abs(centred[, keep, drop = FALSE]) /
            rep(sqrt(diag(cs$v))[keep], each = nrow(centred)), 1, max),
    0.95, type = 7))
  q_hybrid <- SupTCritical(cs$sigma, n_draw = n_draw)
  q_points <- list(
    boot = ComparisonQuantiles(centred, cs$v),
    hybrid = ComparisonQuantiles(NormalDraws(cs$sigma, n_draw), cs$sigma))
  k_hat <- which.max(estimate)

  out <- list(grid = grid, estimate = estimate, completed = completed,
              u = emp$u,
              j_bar = pooled$j_bar, c_hat = c_hat,
              apparent = pooled$index[["p1"]],
              apparent_at_c_hat = at_c_hat,
              c_p2 = pooled$cutoff[["p2"]],
              gap = pooled$index[["p2"]] - pooled$index[["p1"]],
              b_c = pooled$b_c,
              optimism_20 = mean(opt_20), optimism_2 = mean(opt_2),
              corrected_20 = at_c_hat - mean(opt_20),
              corrected_2 = at_c_hat - mean(opt_2), c_bag = c_bag,
              pointwise = pw, rubin = rb, se = se)
  for (con in c("boot", "hybrid")) {
    q <- if (con == "boot") q_boot else q_hybrid
    lower <- estimate - q * se
    upper <- estimate + q * se
    q_comp <- max(q_points[[con]])
    q_plugin <- q_points[[con]][k_hat]
    out[[con]] <- list(
      lower = lower, upper = upper, q = q, q_comp = q_comp,
      q_comp_plugin = q_plugin,
      band_set = upper >= max(lower),
      comp_set = ComparisonSet(estimate, cs$sigma, q_comp),
      comp_set_plugin = ComparisonSet(estimate, cs$sigma, q_plugin))
  }
  out
}
