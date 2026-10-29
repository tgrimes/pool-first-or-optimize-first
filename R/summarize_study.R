# Per-cell summaries of the simulation study (protocol.md): pilot-c's
# measures plus those the design added.

#' Summarize one cell of the simulation study
#'
#' Pilot-c's measures (`SummarizeCellC()`) and, each with its MCSE where it
#' has one: the comparison-based sets with the plug-in critical value; the
#' pooling-order gap against \eqn{\kappa \hat B_c / 2}; the bias, empirical
#' SE, and RMSE of the pooled cutoff, and the RMSE of the averaged and
#' bagged cutoffs; the regret; and, at the grid's best threshold, the
#' averaged curve's bias and the ratio of its Monte Carlo SD to the mean
#' standard error of the bootstrap-then-impute and Rubin's-rules
#' covariances.
#'
#' @param reps Per-replicate rows of one cell, from `RunReplicateC()`.
#' @param truth Output of `MarkerTruth()`.
#' @return A one-row data frame.
#' @export
SummarizeStudyCell <- function(reps, truth) {
  out <- as.list(SummarizeCellC(reps, truth))
  n_rep <- nrow(reps)
  Prop <- function(x) {
    p <- mean(x)
    c(p, sqrt(p * (1 - p) / n_rep))
  }
  for (con in c("boot", "hybrid")) {
    key <- paste0("compplug_", con)
    p <- Prop(reps[[paste0(key, "_contains")]])
    out[[key]] <- p[1]
    out[[paste0(key, "_mcse")]] <- p[2]
    out[[paste0(key, "_length")]] <- mean(reps[[paste0(key, "_length")]])
    lr <- RatioOfMeans(reps[[paste0(key, "_length")]],
                       reps[[paste0("bandset_", con, "_length")]])
    out[[paste0("length_ratio_plug_", con)]] <- lr[["ratio"]]
    out[[paste0("length_ratio_plug_", con, "_mcse")]] <- lr[["mcse"]]
    out[[paste0("q_plug_", con)]] <- mean(reps[[paste0("q_plug_", con)]])
  }
  out$kappa <- truth$kappa
  pred <- truth$kappa * reps$b_c / 2
  out$pred_gap <- mean(pred)
  if (mean(pred) > 0) {
    gr <- RatioOfMeans(reps$gap, pred)
    out$gap_ratio <- gr[["ratio"]]
    out$gap_ratio_mcse <- gr[["mcse"]]
  } else {
    out$gap_ratio <- NA_real_
    out$gap_ratio_mcse <- NA_real_
  }
  err <- reps$c_hat - truth$c_star
  out$cutoff_bias <- mean(err)
  out$cutoff_bias_mcse <- McseMean(err)
  out$cutoff_se <- stats::sd(reps$c_hat)
  rm1 <- RmseMcse(err)
  out$cutoff_rmse <- rm1[["rmse"]]
  out$cutoff_rmse_mcse <- rm1[["mcse"]]
  out$cutoff_rmse_p2 <- sqrt(mean((reps$c_p2 - truth$c_star)^2))
  out$cutoff_rmse_bag <- sqrt(mean((reps$c_bag - truth$c_star)^2))
  rb <- RatioOfMeans((reps$c_bag - truth$c_star)^2, err^2)
  out$rmse_ratio_bag <- sqrt(rb[["ratio"]])
  out$rmse_ratio_bag_mcse <- rb[["mcse"]] / (2 * sqrt(rb[["ratio"]]))
  regret <- truth$j_star - reps$j_at_c_hat
  out$regret <- mean(regret)
  out$regret_mcse <- McseMean(regret)
  e <- reps$est_best - reps$j_best
  out$curve_bias_best <- mean(e)
  out$curve_bias_best_mcse <- McseMean(e)
  out$curve_sd_best <- stats::sd(e)
  out$se_best <- mean(reps$se_best)
  out$se_rubin_best <- mean(reps$se_rubin_best)
  out$sd_se_ratio <- stats::sd(e) / mean(reps$se_best)
  out$sd_se_ratio_rubin <- stats::sd(e) / mean(reps$se_rubin_best)
  out$n_used <- mean(reps$n_used)
  as.data.frame(out)
}

#' Summarize every cell of the simulation study
#'
#' @param replicates Per-replicate rows of all cells and blocks.
#' @param design The design table.
#' @return A data frame, one row per cell, with the design's columns, the
#'   cell's `label` (`CellLabel()`), `c_star`, `j_star`, and the measures.
#' @export
SummarizeStudy <- function(replicates, design) {
  labels <- CellLabel(design)
  rows <- lapply(sort(unique(replicates$cell)), function(k) {
    cell <- design[design$cell == k, ]
    truth <- MarkerTruth(cell$delta, cell$sigma1)
    cbind(cell, label = labels[design$cell == k], c_star = truth$c_star,
          j_star = truth$j_star,
          SummarizeStudyCell(replicates[replicates$cell == k, ], truth))
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

#' One cell of the study's summaries
#'
#' @param s Output of `SummarizeStudy()` (or a design table).
#' @param shape,n,miss_rate,engine The cell's levels.
#' @param n1 Size of group 1; equal to `n` by default.
#' @return The one matching row; an error if there is not exactly one.
#' @export
PickCell <- function(s, shape = "sharp", n = 250L, miss_rate = 0.4,
                     engine = "pmm", n1 = n) {
  n1_col <- if (is.null(s$n1)) s$n else s$n1
  row <- s[s$shape == shape & s$n == n & n1_col == n1 &
             abs(s$miss_rate - miss_rate) < 1e-9 & s$engine == engine, ]
  if (nrow(row) != 1) {
    stop("no single cell: ", shape, ", n = ", n, ", n1 = ", n1, ", ",
         miss_rate, ", ", engine)
  }
  row
}

#' Slope of the optimism against group size on the log scale
#'
#' Weighted least squares of the log optimism on the log group size over
#' the given cells, with weights from the delta-method variances of the log
#' optimism, \eqn{(\mathrm{MCSE}/\mathrm{optimism})^2}; the standard error
#' treats those variances as known. Supplementary note S1.2 predicts a
#' slope near \eqn{-2/3}.
#'
#' @param s Rows of `SummarizeStudy()`, one per group size.
#' @return A named vector with `slope` and `se`.
#' @export
OptimismSlope <- function(s) {
  y <- log(s$optimism)
  x <- log(s$n)
  w <- 1 / (s$optimism_mcse / s$optimism)^2
  xb <- sum(w * x) / sum(w)
  sxx <- sum(w * (x - xb)^2)
  c(slope = sum(w * (x - xb) * y) / sxx, se = sqrt(1 / sxx))
}
