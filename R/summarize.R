# Per-cell summaries with Monte Carlo standard errors (MCSE).

#' Monte Carlo standard error of a mean
#'
#' @param x Per-replicate values.
#' @return \eqn{\mathrm{sd}(x)/\sqrt{R}}.
#' @export
McseMean <- function(x) stats::sd(x) / sqrt(length(x))

#' Ratio of two means and its Monte Carlo standard error
#'
#' Delta method for \eqn{\bar a / \bar b} on paired replicates.
#'
#' @param a,b Paired per-replicate values.
#' @return A named vector with `ratio` and `mcse`.
#' @export
RatioOfMeans <- function(a, b) {
  r <- mean(a) / mean(b)
  v <- (stats::var(a) - 2 * r * stats::cov(a, b) + r^2 * stats::var(b)) /
    (length(a) * mean(b)^2)
  c(ratio = r, mcse = sqrt(max(v, 0)))
}

#' Root mean squared error and its Monte Carlo standard error
#'
#' @param err Per-replicate errors.
#' @return A named vector with `rmse` and `mcse` (delta method).
#' @export
RmseMcse <- function(err) {
  m <- mean(err^2)
  c(rmse = sqrt(m), mcse = McseMean(err^2) / (2 * sqrt(m)))
}

#' Correlation and its Monte Carlo standard error
#'
#' @param x,y Paired per-replicate values.
#' @return A named vector with `r` and `mcse`, \eqn{(1 - r^2)/\sqrt{R - 3}};
#'   `NA` when either has no spread.
#' @export
CorMcse <- function(x, y) {
  if (stats::sd(x) == 0 || stats::sd(y) == 0) return(c(r = NA, mcse = NA))
  r <- stats::cor(x, y)
  c(r = r, mcse = (1 - r^2) / sqrt(length(x) - 3))
}

#' Summarize one analysis cell
#'
#' @param reps Per-replicate rows of one data cell and one estimator, as
#'   returned by `RunDataCell()`.
#' @param truth Output of `MarkerTruth()` for the cell's shape.
#' @return A one-row data frame of measures, each with its MCSE.
#' @export
SummarizeCell <- function(reps, truth) {
  n_rep <- nrow(reps)
  out <- list(n_rep = n_rep, miss_frac = mean(reps$miss_frac))
  for (rule in c("p1", "p2", "p3")) {
    err_c <- reps[[paste0("c_", rule)]] - truth$c_star
    err_j <- reps[[paste0("j_", rule)]] - truth$j_star
    regret <- truth$j_star - reps[[paste0("tj_", rule)]]
    rm <- RmseMcse(err_c)
    out[[paste0("bias_c_", rule)]] <- mean(err_c)
    out[[paste0("bias_c_", rule, "_mcse")]] <- McseMean(err_c)
    out[[paste0("rmse_c_", rule)]] <- rm[["rmse"]]
    out[[paste0("rmse_c_", rule, "_mcse")]] <- rm[["mcse"]]
    out[[paste0("bias_j_", rule)]] <- mean(err_j)
    out[[paste0("bias_j_", rule, "_mcse")]] <- McseMean(err_j)
    out[[paste0("regret_", rule)]] <- mean(regret)
    out[[paste0("regret_", rule, "_mcse")]] <- McseMean(regret)
  }
  bias_ratio <- RatioOfMeans(reps$j_p1 - truth$j_star,
                             reps$j_p2 - truth$j_star)
  out$bias_j_ratio <- bias_ratio[["ratio"]]
  out$bias_j_ratio_mcse <- bias_ratio[["mcse"]]
  gap <- reps$gap
  out$gap <- mean(gap)
  out$gap_mcse <- McseMean(gap)
  out$gap_min <- min(gap)
  out$gap_n_nonzero <- sum(gap != 0)
  out$pred_gap <- mean(reps$pred_gap)
  out$b_c <- mean(reps$b_c)
  if (out$pred_gap > 0) {
    rg <- RatioOfMeans(gap, reps$pred_gap)
    out$gap_ratio <- rg[["ratio"]]
    out$gap_ratio_mcse <- rg[["mcse"]]
  } else {
    out$gap_ratio <- out$gap_ratio_mcse <- NA_real_
  }
  if (all(is.finite(reps$pred_gap_hat)) && mean(reps$pred_gap_hat) > 0) {
    rh <- RatioOfMeans(gap, reps$pred_gap_hat)
    out$gap_ratio_hat <- rh[["ratio"]]
    out$gap_ratio_hat_mcse <- rh[["mcse"]]
  } else {
    out$gap_ratio_hat <- out$gap_ratio_hat_mcse <- NA_real_
  }
  cr <- CorMcse(reps$b_c, gap)
  out$cor_b_gap <- cr[["r"]]
  out$cor_b_gap_mcse <- cr[["mcse"]]
  cdiff <- reps$c_p1 - reps$c_p2
  out$cdiff <- mean(cdiff)
  out$cdiff_mcse <- McseMean(cdiff)
  out$pred_cdiff <- mean(reps$pred_cdiff)
  for (at in c("mid", "lo", "hi")) {
    p <- mean(reps[[paste0("cover_", at)]])
    out[[paste0("cover_", at)]] <- p
    out[[paste0("cover_", at, "_mcse")]] <- sqrt(p * (1 - p) / n_rep)
  }
  out$width_mid <- mean(reps$width_mid)
  sq1 <- (reps$c_p1 - truth$c_star)^2
  sq2 <- (reps$c_p2 - truth$c_star)^2
  if (mean(sq1) > 0) {
    rq <- RatioOfMeans(sq2, sq1)
    out$rmse_ratio <- sqrt(rq[["ratio"]])
    out$rmse_ratio_mcse <- rq[["mcse"]] / (2 * sqrt(rq[["ratio"]]))
  } else {
    out$rmse_ratio <- out$rmse_ratio_mcse <- NA_real_
  }
  as.data.frame(out)
}

#' Summarize every analysis cell
#'
#' @param replicates Per-replicate rows of all cells (`RunDataCell()`
#'   output, bound together).
#' @param design Output of `PilotDesign()`.
#' @return A data frame with one row per data cell and estimator: the design
#'   columns followed by the measures of `SummarizeCell()`.
#' @export
SummarizeAllCells <- function(replicates, design) {
  keys <- unique(replicates[, c("cell", "estimator")])
  rows <- lapply(seq_len(nrow(keys)), function(i) {
    cell <- design[design$cell == keys$cell[i], ]
    reps <- replicates[replicates$cell == keys$cell[i] &
                         replicates$estimator == keys$estimator[i], ]
    truth <- MarkerTruth(cell$delta, cell$sigma1)
    cbind(cell, estimator = keys$estimator[i], c_star = truth$c_star,
          j_star = truth$j_star, kappa = truth$kappa, tau = truth$tau,
          SummarizeCell(reps, truth))
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out[order(out$cell, out$estimator), ]
}
