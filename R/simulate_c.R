# Pilot-c's design, blocks, and replicate (pilot-c/preregistration.md).

#' Pilot-c's design table
#'
#' The sharp shape at 250 per group: no missing values (cell 1), 40% and 60%
#' missing with predictive mean matching or normal imputation.
#'
#' @return A data frame with `cell`, `shape`, `delta`, `sigma1`,
#'   `miss_rate`, `alpha0`, `n`, `engine`, `n_imp`, `base`.
#' @export
PilotDesignC <- function() {
  design <- data.frame(cell = 1:5, shape = "sharp", delta = 2, sigma1 = 1,
                       miss_rate = c(0, 0.4, 0.4, 0.6, 0.6),
                       engine = c("none", "pmm", "norm", "pmm", "norm"),
                       n = 250L, n_imp = 20L)
  design$alpha0 <- NA_real_
  for (i in which(design$miss_rate > 0)) {
    design$alpha0[i] <- MissingIntercept(design$miss_rate[i], 2, 1)
  }
  design$base <- design$cell == 2
  design[, c("cell", "shape", "delta", "sigma1", "miss_rate", "alpha0", "n",
             "engine", "n_imp", "base")]
}

#' Blocks of replicates with their own seeds
#'
#' @param design A design table with a `cell` column.
#' @param n_rep Replicates per cell.
#' @param block_size Replicates per block.
#' @param base_seed Seed offset; block `b` of cell `k` gets
#'   `base_seed + 1000 * k + b`.
#' @return One row per block: the cell's columns, `block`, `n_rep_block`,
#'   and `seed`.
#' @export
BlockTable <- function(design, n_rep, block_size = 100L,
                       base_seed = 20261030L) {
  n_block <- ceiling(n_rep / block_size)
  rows <- lapply(seq_len(nrow(design)), function(i) {
    blocks <- design[rep(i, n_block), ]
    blocks$block <- seq_len(n_block)
    blocks$n_rep_block <- pmin(block_size,
                               n_rep - (blocks$block - 1) * block_size)
    blocks$seed <- base_seed + 1000L * blocks$cell + blocks$block
    blocks
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

#' Run one replicate of pilot-c
#'
#' @param cell One row of `PilotDesignC()` (or of `BlockTable()`).
#' @param truth Output of `MarkerTruth()`.
#' @param n_boot Resamples for the curve, each imputed `m_boot` times.
#' @param m_boot Imputations per curve resample.
#' @param n_boot_opt Resamples for the optimism correction, each imputed
#'   `cell$n_imp` times.
#' @param n_boot_opt2 Curve resamples reused for the 2-imputation
#'   correction.
#' @param grid_n Grid points.
#' @param n_draw Normal draws for the Rubin's-rules and hybrid critical
#'   values.
#' @return A one-row data frame of per-replicate quantities.
#' @export
RunReplicateC <- function(cell, truth, n_boot = 1000L, m_boot = 2L,
                          n_boot_opt = 100L, n_boot_opt2 = 200L,
                          grid_n = 41L, n_draw = 5000L) {
  dat <- SimulateMarkerData(cell$n, cell$delta, cell$sigma1, cell$alpha0)
  x <- if (cell$engine == "none") dat$x_full else dat$x
  d <- dat$d
  n0 <- sum(d == 0)
  n1 <- sum(d == 1)
  completed <- ImputeWith(cell$engine, x, d, dat$z, cell$n_imp)
  true_at <- function(cc) TrueYouden(cc, truth$delta, truth$sigma1)

  emp <- EmpiricalCurves(completed, d)
  pooled <- PoolStepCurves(emp$u, emp$values)
  c_hat <- pooled$cutoff[["p1"]]
  apparent <- pooled$index[["p1"]]
  at_c_hat <- StepValue(c_hat, emp$u, pooled$j_bar)

  grid <- GridFromCompleted(completed, grid_n)
  j_true <- true_at(grid)
  k_best <- which.max(j_true)
  gc <- GridCurves(completed, d, grid)
  estimate <- PoolMean(gc$j)
  pw <- PointwiseRubinBand(gc, n0, n1)
  rb <- RubinBand(gc, n0, n1, n_draw = n_draw)

  # Resamples for the curve; the first n_boot_opt2 also give the
  # 2-imputation optimism.
  boot_grid <- replicate(m_boot, matrix(NA_real_, n_boot, grid_n),
                         simplify = FALSE)
  pooled_2 <- vector("list", n_boot_opt2)
  for (b in seq_len(n_boot)) {
    idx <- ResampleWithinGroups(d)
    comp_b <- ImputeWith(cell$engine, x[idx], d[idx], dat$z[idx], m_boot)
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
    comp_b <- ImputeWith(cell$engine, x[idx], d[idx], dat$z[idx],
                         cell$n_imp)
    emp_b <- EmpiricalCurves(comp_b, d[idx])
    list(u = emp_b$u, j_bar = PoolMean(emp_b$values))
  })
  opt_20 <- BootOptimism(pooled_20, emp$u, pooled$j_bar)
  opt_2 <- BootOptimism(pooled_2, emp$u, pooled$j_bar)

  cs <- CovarianceSplit(boot_grid, cell$n_imp)
  se <- sqrt(diag(cs$sigma))
  centred <- cs$boot_mean - rep(colMeans(cs$boot_mean),
                                each = nrow(cs$boot_mean))
  keep <- diag(cs$v) > 0
  q_boot <- unname(stats::quantile(
    apply(abs(centred[, keep, drop = FALSE]) /
            rep(sqrt(diag(cs$v))[keep], each = nrow(centred)), 1, max),
    0.95, type = 7))
  q_hybrid <- SupTCritical(cs$sigma, n_draw = n_draw)
  bands <- list(
    boot = list(lower = estimate - q_boot * se, upper = estimate + q_boot * se),
    hybrid = list(lower = estimate - q_hybrid * se,
                  upper = estimate + q_hybrid * se))
  qd <- c(boot = ComparisonCritical(centred, cs$v),
          hybrid = ComparisonCritical(NormalDraws(cs$sigma, n_draw),
                                      cs$sigma))

  out <- list(
    c_hat = c_hat, apparent = apparent, apparent_at_c_hat = at_c_hat,
    j_at_c_hat = true_at(c_hat),
    corrected_20 = at_c_hat - mean(opt_20), optimism_20 = mean(opt_20),
    corrected_2 = at_c_hat - mean(opt_2), optimism_2 = mean(opt_2),
    c_p2 = pooled$cutoff[["p2"]], gap = pooled$index[["p2"]] - apparent,
    cover_pointwise = BandCovers(pw$lower, pw$upper, j_true),
    cover_rubin = BandCovers(rb$lower, rb$upper, j_true),
    width_pointwise = mean(pw$upper - pw$lower) / 2,
    width_rubin = mean(rb$upper - rb$lower) / 2,
    q_rubin = rb$q, q_boot = q_boot, q_hybrid = q_hybrid)
  for (con in c("boot", "hybrid")) {
    band <- bands[[con]]
    band_set <- SetOnGrid(grid, band$upper >= max(band$lower), k_best)
    comp_set <- SetOnGrid(grid, ComparisonSet(estimate, cs$sigma, qd[[con]]),
                          k_best)
    out[[paste0("cover_", con)]] <- BandCovers(band$lower, band$upper, j_true)
    out[[paste0("width_", con)]] <- mean(band$upper - band$lower) / 2
    out[[paste0("bandset_", con, "_contains")]] <- band_set$contains
    out[[paste0("bandset_", con, "_length")]] <- band_set$length
    out[[paste0("compset_", con, "_contains")]] <- comp_set$contains
    out[[paste0("compset_", con, "_length")]] <- comp_set$length
    out[[paste0("q_comp_", con)]] <- qd[[con]]
  }
  out$c_star_in_grid <- truth$c_star >= grid[1] &&
    truth$c_star <= grid[grid_n]
  out$grid_lo <- grid[1]
  out$grid_hi <- grid[grid_n]
  out$miss_frac <- mean(!dat$observed)
  as.data.frame(out)
}
