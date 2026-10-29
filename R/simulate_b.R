# The re-pilot's design table and replicate (pilot-b/preregistration.md).
# pilot-b/pilot.R calls these through RunDataCell().

#' The re-pilot's design table
#'
#' Per shape, a null cell (0% missing, no imputation) and four imputed cells
#' (40% and 60% missing, predictive mean matching and normal imputation), at
#' 250 per group. Cell `k` is seeded with `base_seed + k`.
#'
#' @param base_seed Seed offset.
#' @return A data frame with `cell`, `shape`, `delta`, `sigma1`,
#'   `miss_rate`, `alpha0`, `n`, `engine`, `n_imp`, `seed`, `base`.
#' @export
PilotDesignB <- function(base_seed = 20261029L) {
  shapes <- data.frame(shape = c("sharp", "flat"), delta = c(2, 1.5),
                       sigma1 = c(1, 2.5))
  rows <- list()
  for (i in seq_len(nrow(shapes))) {
    cells <- data.frame(miss_rate = c(0, 0.4, 0.4, 0.6, 0.6),
                        engine = c("none", "pmm", "norm", "pmm", "norm"))
    cells$shape <- shapes$shape[i]
    cells$delta <- shapes$delta[i]
    cells$sigma1 <- shapes$sigma1[i]
    rows[[i]] <- cells
  }
  design <- do.call(rbind, rows)
  design$n <- 250L
  design$n_imp <- 20L
  design$alpha0 <- NA_real_
  for (i in which(design$miss_rate > 0)) {
    design$alpha0[i] <- MissingIntercept(design$miss_rate[i],
                                         design$delta[i], design$sigma1[i])
  }
  design$cell <- seq_len(nrow(design))
  design$seed <- base_seed + design$cell
  design$base <- design$shape == "sharp" & design$miss_rate == 0.4 &
    design$engine == "pmm"
  design[, c("cell", "shape", "delta", "sigma1", "miss_rate", "alpha0", "n",
             "engine", "n_imp", "seed", "base")]
}

#' Run one replicate of the re-pilot
#'
#' Simulates a dataset, imputes it `n_imp` times, pools the empirical curves,
#' builds the three bands on a grid between the 10% and 90% quantiles of the
#' observed marker, and runs the bootstrap-then-impute loop for the band and
#' the optimism correction.
#'
#' @param cell One row of `PilotDesignB()`.
#' @param truth Output of `MarkerTruth()` for the cell's shape.
#' @param n_boot Bootstrap resamples \eqn{R_B}.
#' @param m_boot Imputations per resample \eqn{M}.
#' @param grid_n Grid points \eqn{K}.
#' @param n_draw Draws for the Rubin sup-t critical value.
#' @return A one-row data frame of per-replicate quantities.
#' @export
RunReplicateB <- function(cell, truth, n_boot = 200L, m_boot = 2L,
                          grid_n = 41L, n_draw = 5000L) {
  dat <- SimulateMarkerData(cell$n, cell$delta, cell$sigma1, cell$alpha0)
  x <- if (cell$engine == "none") dat$x_full else dat$x
  d <- dat$d
  n0 <- sum(d == 0)
  n1 <- sum(d == 1)
  completed <- ImputeWith(cell$engine, x, d, dat$z, cell$n_imp)

  # The pooled step curve, its maximizer, and the pooling-order note.
  emp <- EmpiricalCurves(completed, d)
  pooled <- PoolStepCurves(emp$u, emp$values)
  c_hat <- pooled$cutoff[["p1"]]
  apparent <- pooled$index[["p1"]]
  true_at <- function(cc) TrueYouden(cc, truth$delta, truth$sigma1)

  # The grid and the bands.
  obs_x <- x[!is.na(x)]
  grid <- seq(stats::quantile(obs_x, 0.1), stats::quantile(obs_x, 0.9),
              length.out = grid_n)
  j_true <- true_at(grid)
  gc <- GridCurves(completed, d, grid)
  pw <- PointwiseRubinBand(gc, n0, n1)
  rb <- RubinBand(gc, n0, n1, n_draw = n_draw)

  # Bootstrap-then-impute: grid curves for the band, pooled maxima for the
  # optimism correction.
  boot_grid <- replicate(m_boot, matrix(NA_real_, n_boot, grid_n),
                         simplify = FALSE)
  boot_pooled <- vector("list", n_boot)
  for (b in seq_len(n_boot)) {
    idx <- ResampleWithinGroups(d)
    comp_b <- ImputeWith(cell$engine, x[idx], d[idx], dat$z[idx], m_boot)
    gb <- GridCurves(comp_b, d[idx], grid)
    for (m in seq_len(m_boot)) boot_grid[[m]][b, ] <- gb$j[m, ]
    emp_b <- EmpiricalCurves(comp_b, d[idx])
    boot_pooled[[b]] <- list(u = emp_b$u, j_bar = PoolMean(emp_b$values))
  }
  bb <- BootImputeBand(boot_grid, rb$estimate, cell$n_imp)
  optimism <- BootOptimism(boot_pooled, emp$u, pooled$j_bar)
  at_c_hat <- StepValue(c_hat, emp$u, pooled$j_bar)
  corrected <- at_c_hat - mean(optimism)

  set_r <- NearOptimalSet(grid, rb$lower, rb$upper, truth$c_star)
  set_b <- NearOptimalSet(grid, bb$lower, bb$upper, truth$c_star)
  k_mid <- which.min(abs(grid - truth$c_star))
  f_star <- GroupCdfAt(truth$c_star, completed, d, "empirical")
  ri_star <- RubinInterval(f_star[, "f0"] - f_star[, "f1"],
                           f_star[, "f0"] * (1 - f_star[, "f0"]) / n0 +
                             f_star[, "f1"] * (1 - f_star[, "f1"]) / n1)
  j_star_true <- truth$j_star

  data.frame(
    c_hat = c_hat, apparent = apparent, apparent_at_c_hat = at_c_hat,
    j_at_c_hat = true_at(c_hat),
    corrected = corrected, mean_optimism = mean(optimism),
    c_p2 = pooled$cutoff[["p2"]], gap = pooled$index[["p2"]] - apparent,
    b_c = pooled$b_c, pred_gap = truth$kappa * pooled$b_c / 2,
    cover_pointwise = BandCovers(pw$lower, pw$upper, j_true),
    cover_rubin = BandCovers(rb$lower, rb$upper, j_true),
    cover_boot = BandCovers(bb$lower, bb$upper, j_true),
    width_pointwise = mean(pw$upper - pw$lower) / 2,
    width_rubin = mean(rb$upper - rb$lower) / 2,
    width_boot = mean(bb$upper - bb$lower) / 2,
    q_rubin = rb$q, q_boot = bb$q,
    set_rubin_contains = set_r$contains, set_rubin_length = set_r$length,
    set_boot_contains = set_b$contains, set_boot_length = set_b$length,
    cover_star = ri_star$lower <= j_star_true && j_star_true <= ri_star$upper,
    grid_lo = grid[1], grid_hi = grid[grid_n], k_mid = k_mid,
    miss_frac = mean(!dat$observed))
}
