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

#' Run one replicate of the simulation study
#'
#' Simulates a dataset for the cell, applies `MiYoudenInference()`, and
#' compares its output with the truth. Written for pilot-c and extended for
#' the study's design: the engine `"cc"` analyses the complete cases without
#' imputation, `"pmm10"` matches on 10 donors, and a column `n1` in the cell
#' sets the size of group 1 (equal to `n` when absent). The order of random
#' draws is pilot-c's, so pilot-c's replicates are reproduced exactly.
#'
#' @param cell One row of a design table (or of `BlockTable()`).
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
  n1 <- if (is.null(cell$n1)) cell$n else cell$n1
  dat <- SimulateMarkerData(cell$n, cell$delta, cell$sigma1, cell$alpha0,
                            n1 = n1)
  engine <- cell$engine
  if (engine == "cc") {
    dat_used <- dat[dat$observed, ]
    engine <- "none"
  } else {
    dat_used <- dat
  }
  x <- if (engine == "none") dat_used$x_full else dat_used$x
  d <- dat_used$d
  z <- dat_used$z
  Impute <- function(rows, m) ImputeWith(engine, x[rows], d[rows], z[rows], m)
  true_at <- function(cc) TrueYouden(cc, truth$delta, truth$sigma1)

  res <- MiYoudenInference(d, Impute, n_imp = cell$n_imp, n_boot = n_boot,
                           m_boot = m_boot, n_boot_opt = n_boot_opt,
                           n_boot_opt2 = n_boot_opt2, grid_n = grid_n,
                           n_draw = n_draw)
  grid <- res$grid
  j_true <- true_at(grid)
  k_best <- which.max(j_true)

  out <- list(
    c_hat = res$c_hat, apparent = res$apparent,
    apparent_at_c_hat = res$apparent_at_c_hat,
    j_at_c_hat = true_at(res$c_hat),
    corrected_20 = res$corrected_20, optimism_20 = res$optimism_20,
    corrected_2 = res$corrected_2, optimism_2 = res$optimism_2,
    c_p2 = res$c_p2, gap = res$gap,
    cover_pointwise = BandCovers(res$pointwise$lower, res$pointwise$upper,
                                 j_true),
    cover_rubin = BandCovers(res$rubin$lower, res$rubin$upper, j_true),
    width_pointwise = mean(res$pointwise$upper - res$pointwise$lower) / 2,
    width_rubin = mean(res$rubin$upper - res$rubin$lower) / 2,
    q_rubin = res$rubin$q, q_boot = res$boot$q, q_hybrid = res$hybrid$q)
  for (con in c("boot", "hybrid")) {
    r <- res[[con]]
    band_set <- SetOnGrid(grid, r$band_set, k_best)
    comp_set <- SetOnGrid(grid, r$comp_set, k_best)
    out[[paste0("cover_", con)]] <- BandCovers(r$lower, r$upper, j_true)
    out[[paste0("width_", con)]] <- mean(r$upper - r$lower) / 2
    out[[paste0("bandset_", con, "_contains")]] <- band_set$contains
    out[[paste0("bandset_", con, "_length")]] <- band_set$length
    out[[paste0("compset_", con, "_contains")]] <- comp_set$contains
    out[[paste0("compset_", con, "_length")]] <- comp_set$length
    out[[paste0("q_comp_", con)]] <- r$q_comp
  }
  out$c_star_in_grid <- truth$c_star >= grid[1] &&
    truth$c_star <= grid[grid_n]
  out$grid_lo <- grid[1]
  out$grid_hi <- grid[grid_n]
  out$miss_frac <- mean(!dat$observed)
  # Added for the study's design (protocol.md); none draws random numbers.
  for (con in c("boot", "hybrid")) {
    plug <- SetOnGrid(grid, res[[con]]$comp_set_plugin, k_best)
    out[[paste0("compplug_", con, "_contains")]] <- plug$contains
    out[[paste0("compplug_", con, "_length")]] <- plug$length
    out[[paste0("q_plug_", con)]] <- res[[con]]$q_comp_plugin
  }
  out$b_c <- res$b_c
  out$c_bag <- res$c_bag
  out$est_best <- res$estimate[k_best]
  out$j_best <- j_true[k_best]
  out$se_best <- res$se[k_best]
  out$se_rubin_best <- res$rubin$se[k_best]
  out$n_used <- length(d)
  as.data.frame(out)
}
