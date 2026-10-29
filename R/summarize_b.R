# The re-pilot's per-cell summaries and pass rule
# (pilot-b/preregistration.md, sections 3 and 5).

#' Summarize one re-pilot cell
#'
#' @param reps Per-replicate rows of one cell, from `RunDataCell()` with
#'   `RunReplicateB()`.
#' @param truth Output of `MarkerTruth()` for the cell's shape.
#' @return A one-row data frame of measures, each with its MCSE.
#' @export
SummarizeCellB <- function(reps, truth) {
  n_rep <- nrow(reps)
  Prop <- function(x) {
    p <- mean(x)
    c(p, sqrt(p * (1 - p) / n_rep))
  }
  out <- list(n_rep = n_rep, miss_frac = mean(reps$miss_frac))
  opt <- reps$apparent - reps$j_at_c_hat
  cor_err <- reps$corrected - reps$j_at_c_hat
  out$optimism <- mean(opt)
  out$optimism_mcse <- McseMean(opt)
  out$apparent_bias_star <- mean(reps$apparent - truth$j_star)
  out$apparent_bias_star_mcse <- McseMean(reps$apparent - truth$j_star)
  out$corrected_bias <- mean(cor_err)
  out$corrected_bias_mcse <- McseMean(cor_err)
  out$corrected_bias_star <- mean(reps$corrected - truth$j_star)
  out$corrected_bias_star_mcse <- McseMean(reps$corrected - truth$j_star)
  rr <- RatioOfMeans(cor_err, opt)
  out$bias_ratio <- rr[["ratio"]]
  out$bias_ratio_mcse <- rr[["mcse"]]
  out$mean_boot_optimism <- mean(reps$mean_optimism)
  for (band in c("pointwise", "rubin", "boot")) {
    p <- Prop(reps[[paste0("cover_", band)]])
    out[[paste0("cover_", band)]] <- p[1]
    out[[paste0("cover_", band, "_mcse")]] <- p[2]
    out[[paste0("width_", band)]] <- mean(reps[[paste0("width_", band)]])
  }
  for (band in c("rubin", "boot")) {
    p <- Prop(reps[[paste0("set_", band, "_contains")]])
    out[[paste0("set_", band)]] <- p[1]
    out[[paste0("set_", band, "_mcse")]] <- p[2]
    out[[paste0("set_", band, "_length")]] <-
      mean(reps[[paste0("set_", band, "_length")]])
  }
  p <- Prop(reps$cover_star)
  out$cover_star <- p[1]
  out$cover_star_mcse <- p[2]
  out$q_rubin <- mean(reps$q_rubin)
  out$q_boot <- mean(reps$q_boot)
  out$gap <- mean(reps$gap)
  out$gap_mcse <- McseMean(reps$gap)
  out$gap_n_nonzero <- sum(reps$gap != 0)
  out$pred_gap <- mean(reps$pred_gap)
  sq1 <- (reps$c_hat - truth$c_star)^2
  sq2 <- (reps$c_p2 - truth$c_star)^2
  out$rmse_c_p1 <- sqrt(mean(sq1))
  out$rmse_c_p2 <- sqrt(mean(sq2))
  rq <- RatioOfMeans(sq2, sq1)
  out$rmse_ratio <- sqrt(rq[["ratio"]])
  out$rmse_ratio_mcse <- rq[["mcse"]] / (2 * sqrt(rq[["ratio"]]))
  out$grid_lo <- mean(reps$grid_lo)
  out$grid_hi <- mean(reps$grid_hi)
  out$c_star_in_grid <- mean(reps$grid_lo <= truth$c_star &
                               truth$c_star <= reps$grid_hi)
  as.data.frame(out)
}

#' Summarize every re-pilot cell
#'
#' @param replicates Per-replicate rows of all cells, bound together.
#' @param design Output of `PilotDesignB()`.
#' @return A data frame, one row per cell: the design columns, the truth,
#'   and the measures of `SummarizeCellB()`.
#' @export
SummarizeAllCellsB <- function(replicates, design) {
  rows <- lapply(sort(unique(replicates$cell)), function(k) {
    cell <- design[design$cell == k, ]
    truth <- MarkerTruth(cell$delta, cell$sigma1)
    cbind(cell, c_star = truth$c_star, j_star = truth$j_star,
          kappa = truth$kappa,
          SummarizeCellB(replicates[replicates$cell == k, ], truth))
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

#' Apply the re-pilot's pre-registered pass rule
#'
#' @param summaries Output of `SummarizeAllCellsB()`.
#' @return A list with `criteria`, `questions`, and `status`, as
#'   `ApplyPassRule()` returns.
#' @export
ApplyPassRuleB <- function(summaries) {
  s <- summaries
  Pick <- function(miss, engine) {
    r <- s[s$shape == "sharp" & s$miss_rate == miss & s$engine == engine, ]
    stopifnot(nrow(r) == 1)
    r
  }
  base <- Pick(0.4, "pmm")
  base_n <- Pick(0.4, "norm")
  sixty <- Pick(0.6, "pmm")
  lab <- c(base = "base (sharp, 40%, 250, PMM)",
           norm = "normal twin (sharp, 40%, 250, normal)",
           sixty = "60% (sharp, 250, PMM)")
  q1 <- rbind(
    Criterion("Q1", "a", lab[["base"]], "optimism of the apparent index",
              base$optimism, base$optimism_mcse, "> 3 MCSE",
              base$optimism > 3 * base$optimism_mcse,
              abs(base$optimism - 3 * base$optimism_mcse)),
    Criterion("Q1", "b", lab[["base"]],
              "simultaneous coverage of pointwise intervals",
              base$cover_pointwise, base$cover_pointwise_mcse, "< 0.90",
              base$cover_pointwise < 0.90,
              abs(base$cover_pointwise - 0.90)))
  q2 <- rbind(
    Criterion("Q2", "a", lab[["base"]], "optimism of the apparent index",
              base$optimism, base$optimism_mcse, ">= 0.01",
              base$optimism >= 0.01, abs(base$optimism - 0.01)),
    Criterion("Q2", "a", lab[["sixty"]], "optimism of the apparent index",
              sixty$optimism, sixty$optimism_mcse, ">= 0.01",
              sixty$optimism >= 0.01, abs(sixty$optimism - 0.01)))
  q3 <- rbind(
    Criterion("Q3", "a", lab[["base"]],
              "|corrected bias| / |apparent optimism|",
              abs(base$bias_ratio), base$bias_ratio_mcse, "<= 0.5",
              isTRUE(abs(base$bias_ratio) <= 0.5),
              abs(abs(base$bias_ratio) - 0.5)))
  for (r in list(list(base, lab[["base"]]), list(base_n, lab[["norm"]]))) {
    x <- r[[1]]
    q3 <- rbind(q3,
      Criterion("Q3", "b", r[[2]], "simultaneous coverage, bootstrap band",
                x$cover_boot, x$cover_boot_mcse, "in [0.92, 0.98]",
                x$cover_boot >= 0.92 && x$cover_boot <= 0.98,
                min(abs(x$cover_boot - 0.92), abs(x$cover_boot - 0.98))),
      Criterion("Q3", "c", r[[2]],
                "near-optimal set contains c*, bootstrap band",
                x$set_boot, x$set_boot_mcse, ">= 0.92",
                x$set_boot >= 0.92, abs(x$set_boot - 0.92)))
  }
  criteria <- rbind(q1, q2, q3)
  passed <- c(Q1 = all(q1$met), Q2 = any(q2$met), Q3 = all(q3$met))
  near <- c(Q1 = RuleNear(q1, TRUE), Q2 = RuleNear(q2, FALSE),
            Q3 = RuleNear(q3, TRUE))
  status <- if (!passed[["Q1"]]) {
    "piloted-fail"
  } else if (!passed[["Q3"]] && !near[["Q3"]]) {
    "piloted-fail"
  } else if (all(passed) && !any(near)) {
    "piloted-pass"
  } else {
    "piloted-close-call"
  }
  list(criteria = criteria,
       questions = data.frame(question = names(passed), passed = passed,
                              near = near, row.names = NULL),
       status = status)
}
