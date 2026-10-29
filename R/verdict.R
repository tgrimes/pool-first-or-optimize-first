# The pilot's pass rule, as pre-registered in pilot/preregistration.md,
# section 5. pilot/verdict.R calls ApplyPassRule() on the saved summaries.

#' One criterion of the pass rule
#'
#' @param question,clause Labels (`"Q1"`, `"a"`).
#' @param cell_label Plain description of the cell judged.
#' @param measure Name of the measure.
#' @param estimate,mcse The estimate and its Monte Carlo standard error.
#' @param rule Text of the threshold.
#' @param met Logical, the threshold is met.
#' @param distance Distance from the estimate to the nearest threshold.
#' @return A one-row data frame; `near` is `distance < 3 * mcse`.
#' @keywords internal
Criterion <- function(question, clause, cell_label, measure, estimate, mcse,
                      rule, met, distance) {
  data.frame(question = question, clause = clause, cell = cell_label,
             measure = measure, estimate = estimate, mcse = mcse,
             rule = rule, met = met,
             near = !is.na(mcse) && distance < 3 * mcse,
             stringsAsFactors = FALSE)
}

#' Whether a rule is near its threshold
#'
#' A rule met through any one clause is near when every met clause is near
#' (or, when none is met, when any clause is near). A rule that needs all
#' its clauses is near, when met, if any clause is near; when not met, if
#' every failed clause is near.
#'
#' @param crit Criterion rows of one question.
#' @param needs_all Logical, the rule needs all its clauses.
#' @return Logical.
#' @keywords internal
RuleNear <- function(crit, needs_all) {
  if (needs_all) {
    if (all(crit$met)) return(any(crit$near))
    return(all(crit$near[!crit$met]))
  }
  if (any(crit$met)) return(all(crit$near[crit$met]))
  any(crit$near)
}

#' Apply the pre-registered pass rule
#'
#' @param summaries Output of `SummarizeAllCells()`.
#' @return A list with `criteria` (one row per criterion), `questions` (one
#'   row per question: passed, near), `status`, and `largest_gap` (the
#'   largest mean gap over the predictive-mean-matching cells with missing
#'   values, with its cell).
#' @export
ApplyPassRule <- function(summaries) {
  s <- summaries
  pmm <- s$engine == "pmm"
  base_rows <- s$shape == "sharp" & s$miss_rate == 0.4 & s$n == 250 &
    pmm & s$n_imp == 20
  base <- s[base_rows & s$estimator == "empirical", ]
  base_k <- s[base_rows & s$estimator == "kernel", ]
  null <- s[s$shape == "sharp" & s$miss_rate == 0 & s$n == 250 &
              s$estimator == "empirical", ]
  sixty <- s[s$shape == "sharp" & s$miss_rate == 0.6 & s$n == 250 & pmm &
               s$n_imp == 20, ]
  stopifnot(nrow(base) == 1, nrow(base_k) == 1, nrow(null) == 1,
            nrow(sixty) == 2)
  lab_base <- "base (sharp, 40%, 250, PMM, L = 20, empirical)"
  lab_base_k <- "base, kernel"
  q1 <- rbind(
    Criterion("Q1", "a", lab_base, "mean gap", base$gap, base$gap_mcse,
              "> 3 MCSE", base$gap > 3 * base$gap_mcse,
              abs(base$gap - 3 * base$gap_mcse)),
    Criterion("Q1", "b", "null (sharp, 0%, 250, empirical)",
              "replicates with a nonzero gap", null$gap_n_nonzero, NA,
              "= 0", null$gap_n_nonzero == 0, NA))
  q2 <- rbind(
    Criterion("Q2", "a", lab_base, "mean gap", base$gap, base$gap_mcse,
              ">= 0.01", base$gap >= 0.01, abs(base$gap - 0.01)),
    Criterion("Q2", "a", lab_base_k, "mean gap", base_k$gap,
              base_k$gap_mcse, ">= 0.01", base_k$gap >= 0.01,
              abs(base_k$gap - 0.01)))
  for (i in seq_len(nrow(sixty))) {
    r <- sixty[i, ]
    q2 <- rbind(q2, Criterion(
      "Q2", "b", paste0("60% (sharp, 250, PMM, ", r$estimator, ")"),
      "mean gap", r$gap, r$gap_mcse, ">= 0.02", r$gap >= 0.02,
      abs(r$gap - 0.02)))
  }
  rmse_cells <- s[pmm & s$miss_rate > 0, ]
  for (i in seq_len(nrow(rmse_cells))) {
    r <- rmse_cells[i, ]
    q2 <- rbind(q2, Criterion(
      "Q2", "c", sprintf("%s, %d%%, %d, PMM, L = %d, %s", r$shape,
                         round(100 * r$miss_rate), r$n, r$n_imp,
                         r$estimator),
      "RMSE ratio of the cutoff, P2 over P1", r$rmse_ratio,
      r$rmse_ratio_mcse, ">= 1.10 or <= 0.90",
      r$rmse_ratio >= 1.10 || r$rmse_ratio <= 0.90,
      min(abs(r$rmse_ratio - 1.10), abs(r$rmse_ratio - 0.90))))
  }
  q3 <- rbind(
    Criterion("Q3", "a", lab_base, "|P1 index bias| / |P2 index bias|",
              abs(base$bias_j_ratio), base$bias_j_ratio_mcse, "<= 0.5",
              abs(base$bias_j_ratio) <= 0.5, abs(abs(base$bias_j_ratio) -
                                                  0.5)),
    Criterion("Q3", "a", lab_base, "P1 index bias", base$bias_j_p1,
              base$bias_j_p1_mcse, "beyond 3 MCSE",
              abs(base$bias_j_p1) > 3 * base$bias_j_p1_mcse,
              abs(abs(base$bias_j_p1) - 3 * base$bias_j_p1_mcse)),
    Criterion("Q3", "a", lab_base, "P2 index bias", base$bias_j_p2,
              base$bias_j_p2_mcse, "beyond 3 MCSE",
              abs(base$bias_j_p2) > 3 * base$bias_j_p2_mcse,
              abs(abs(base$bias_j_p2) - 3 * base$bias_j_p2_mcse)),
    Criterion("Q3", "b", lab_base, "correlation of B_c with the gap",
              base$cor_b_gap, base$cor_b_gap_mcse, ">= 0.5",
              isTRUE(base$cor_b_gap >= 0.5), abs(base$cor_b_gap - 0.5)),
    Criterion("Q3", "b", lab_base_k, "gap / (kappa B_c / 2)",
              base_k$gap_ratio, base_k$gap_ratio_mcse, "in [0.5, 2]",
              isTRUE(base_k$gap_ratio >= 0.5 && base_k$gap_ratio <= 2),
              min(abs(base_k$gap_ratio - 0.5), abs(base_k$gap_ratio - 2))),
    Criterion("Q3", "c", lab_base_k, "coverage of the interval for J(c*)",
              base_k$cover_mid, base_k$cover_mid_mcse, "in [0.92, 0.98]",
              base_k$cover_mid >= 0.92 && base_k$cover_mid <= 0.98,
              min(abs(base_k$cover_mid - 0.92),
                  abs(base_k$cover_mid - 0.98))))
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
  gaps <- s[pmm & s$miss_rate > 0, ]
  largest <- gaps[which.max(gaps$gap), ]
  list(criteria = criteria,
       questions = data.frame(question = names(passed), passed = passed,
                              near = near, row.names = NULL),
       status = status,
       largest_gap = data.frame(
         gap = largest$gap, gap_mcse = largest$gap_mcse,
         cell = sprintf("%s, %d%%, %d, PMM, L = %d, %s", largest$shape,
                        round(100 * largest$miss_rate), largest$n,
                        largest$n_imp, largest$estimator),
         all_below_0005 = all(gaps$gap < 0.005)))
}
