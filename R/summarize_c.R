# Pilot-c's per-cell summaries and pass rule
# (pilot-c/preregistration.md, sections 3 and 5).

#' Summarize one pilot-c cell
#'
#' @param reps Per-replicate rows of one cell, from `RunReplicateC()`.
#' @param truth Output of `MarkerTruth()`.
#' @return A one-row data frame of measures, each with its MCSE.
#' @export
SummarizeCellC <- function(reps, truth) {
  n_rep <- nrow(reps)
  Prop <- function(x) {
    p <- mean(x)
    c(p, sqrt(p * (1 - p) / n_rep))
  }
  out <- list(n_rep = n_rep, miss_frac = mean(reps$miss_frac))
  opt <- reps$apparent - reps$j_at_c_hat
  out$optimism <- mean(opt)
  out$optimism_mcse <- McseMean(opt)
  out$apparent_bias_star <- mean(reps$apparent - truth$j_star)
  out$apparent_bias_star_mcse <- McseMean(reps$apparent - truth$j_star)
  for (m in c("20", "2")) {
    err <- reps[[paste0("corrected_", m)]] - reps$j_at_c_hat
    out[[paste0("corrected_bias_", m)]] <- mean(err)
    out[[paste0("corrected_bias_", m, "_mcse")]] <- McseMean(err)
    out[[paste0("correction_", m)]] <- mean(reps[[paste0("optimism_", m)]])
    rr <- RatioOfMeans(err, opt)
    out[[paste0("bias_ratio_", m)]] <- rr[["ratio"]]
    out[[paste0("bias_ratio_", m, "_mcse")]] <- rr[["mcse"]]
  }
  for (band in c("pointwise", "rubin", "boot", "hybrid")) {
    p <- Prop(reps[[paste0("cover_", band)]])
    out[[paste0("cover_", band)]] <- p[1]
    out[[paste0("cover_", band, "_mcse")]] <- p[2]
    out[[paste0("width_", band)]] <- mean(reps[[paste0("width_", band)]])
  }
  for (con in c("boot", "hybrid")) {
    for (set in c("bandset", "compset")) {
      key <- paste0(set, "_", con)
      p <- Prop(reps[[paste0(key, "_contains")]])
      out[[key]] <- p[1]
      out[[paste0(key, "_mcse")]] <- p[2]
      out[[paste0(key, "_length")]] <- mean(reps[[paste0(key, "_length")]])
    }
    lr <- RatioOfMeans(reps[[paste0("compset_", con, "_length")]],
                       reps[[paste0("bandset_", con, "_length")]])
    out[[paste0("length_ratio_", con)]] <- lr[["ratio"]]
    out[[paste0("length_ratio_", con, "_mcse")]] <- lr[["mcse"]]
    out[[paste0("q_comp_", con)]] <- mean(reps[[paste0("q_comp_", con)]])
  }
  out$q_rubin <- mean(reps$q_rubin)
  out$q_boot <- mean(reps$q_boot)
  out$q_hybrid <- mean(reps$q_hybrid)
  out$c_star_in_grid <- mean(reps$c_star_in_grid)
  out$grid_lo <- mean(reps$grid_lo)
  out$grid_hi <- mean(reps$grid_hi)
  out$true_region_length <- TrueNearRegionLength(truth$delta, truth$sigma1)
  out$gap <- mean(reps$gap)
  out$gap_mcse <- McseMean(reps$gap)
  out$gap_n_nonzero <- sum(reps$gap != 0)
  sq1 <- (reps$c_hat - truth$c_star)^2
  sq2 <- (reps$c_p2 - truth$c_star)^2
  rq <- RatioOfMeans(sq2, sq1)
  out$rmse_ratio <- sqrt(rq[["ratio"]])
  out$rmse_ratio_mcse <- rq[["mcse"]] / (2 * sqrt(rq[["ratio"]]))
  as.data.frame(out)
}

#' Summarize every pilot-c cell
#'
#' @param replicates Per-replicate rows of all cells and blocks.
#' @param design Output of `PilotDesignC()`.
#' @return A data frame, one row per cell.
#' @export
SummarizeAllCellsC <- function(replicates, design) {
  rows <- lapply(sort(unique(replicates$cell)), function(k) {
    cell <- design[design$cell == k, ]
    truth <- MarkerTruth(cell$delta, cell$sigma1)
    cbind(cell, c_star = truth$c_star, j_star = truth$j_star,
          SummarizeCellC(replicates[replicates$cell == k, ], truth))
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

#' Apply pilot-c's pre-registered pass rule
#'
#' @param summaries Output of `SummarizeAllCellsC()`.
#' @return A list with `criteria`, `questions`, `constructions` (whether
#'   each construction passes and is near), and `status`.
#' @export
ApplyPassRuleC <- function(summaries) {
  s <- summaries
  Pick <- function(k) {
    r <- s[s$cell == k, ]
    stopifnot(nrow(r) == 1)
    r
  }
  null <- Pick(1)
  base <- Pick(2)
  twin <- Pick(3)
  sixty <- Pick(4)
  lab <- c(`1` = "null (no missing values)", `2` = "base (40%, PMM)",
           `3` = "normal twin (40%, normal)", `4` = "60% (PMM)")
  Lab <- function(r) lab[[as.character(r$cell)]]
  q1 <- rbind(
    Criterion("Q1", "a", Lab(base), "optimism of the apparent index",
              base$optimism, base$optimism_mcse, "> 3 MCSE",
              base$optimism > 3 * base$optimism_mcse,
              abs(base$optimism - 3 * base$optimism_mcse)),
    Criterion("Q1", "b", Lab(base),
              "simultaneous coverage of pointwise intervals",
              base$cover_pointwise, base$cover_pointwise_mcse, "< 0.90",
              base$cover_pointwise < 0.90, abs(base$cover_pointwise - 0.90)))
  q2 <- do.call(rbind, lapply(list(base, sixty), function(r) {
    Criterion("Q2", "a", Lab(r), "optimism of the apparent index",
              r$optimism, r$optimism_mcse, ">= 0.01", r$optimism >= 0.01,
              abs(r$optimism - 0.01))
  }))
  q3a <- do.call(rbind, lapply(list(base, twin), function(r) {
    Criterion("Q3", "a", Lab(r),
              "|corrected bias, 20 imputations| / optimism",
              abs(r$bias_ratio_20), r$bias_ratio_20_mcse, "<= 0.5",
              isTRUE(abs(r$bias_ratio_20) <= 0.5),
              abs(abs(r$bias_ratio_20) - 0.5))
  }))
  con_rows <- list()
  for (con in c("boot", "hybrid")) {
    cl <- paste0("b, ", con)
    rows <- list()
    for (r in list(null, base, twin)) {
      cov <- r[[paste0("cover_", con)]]
      rows[[length(rows) + 1]] <- Criterion(
        "Q3", cl, Lab(r), "simultaneous coverage of the band", cov,
        r[[paste0("cover_", con, "_mcse")]], "in [0.93, 0.97]",
        cov >= 0.93 && cov <= 0.97,
        min(abs(cov - 0.93), abs(cov - 0.97)))
    }
    for (r in list(base, twin)) {
      p <- r[[paste0("compset_", con)]]
      rows[[length(rows) + 1]] <- Criterion(
        "Q3", cl, Lab(r), "comparison-based set contains the best threshold",
        p, r[[paste0("compset_", con, "_mcse")]], ">= 0.93", p >= 0.93,
        abs(p - 0.93))
      lr <- r[[paste0("length_ratio_", con)]]
      rows[[length(rows) + 1]] <- Criterion(
        "Q3", cl, Lab(r), "set length / band-based set length", lr,
        r[[paste0("length_ratio_", con, "_mcse")]], "<= 0.75",
        isTRUE(lr <= 0.75), abs(lr - 0.75))
    }
    con_rows[[con]] <- do.call(rbind, rows)
  }
  criteria <- rbind(q1, q2, q3a, con_rows$boot, con_rows$hybrid)
  con_met <- vapply(con_rows, function(x) all(x$met), logical(1))
  con_near <- vapply(con_rows, function(x) RuleNear(x, TRUE), logical(1))
  a_met <- all(q3a$met)
  a_near <- RuleNear(q3a, TRUE)
  q3_met <- a_met && any(con_met)
  q3_near <- if (q3_met) {
    a_near || all(con_near[con_met])
  } else {
    (a_met || a_near) && any(con_met | con_near)
  }
  passed <- c(Q1 = all(q1$met), Q2 = any(q2$met), Q3 = q3_met)
  near <- c(Q1 = RuleNear(q1, TRUE), Q2 = RuleNear(q2, FALSE), Q3 = q3_near)
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
       constructions = data.frame(construction = names(con_met),
                                  passed = con_met, near = con_near,
                                  row.names = NULL),
       status = status)
}
