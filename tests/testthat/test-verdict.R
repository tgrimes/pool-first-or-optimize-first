# Tests for R/verdict.R: the pre-registered pass rule, on fake summaries
# whose every number is chosen so the verdict is known.

# Logical index of the summary rows of one cell (both estimators unless
# `est` is given).
CellRows <- function(s, shape = "sharp", miss = 0.4, n = 250,
                     engine = "pmm", n_imp = 20, est = NULL) {
  keep <- s$shape == shape & s$miss_rate == miss & s$n == n &
    s$engine == engine & s$n_imp == n_imp
  if (!is.null(est)) keep <- keep & s$estimator == est
  keep
}

# 22 data cells x 2 estimators, every number a clear pass of the rule: the
# gaps are large relative to their MCSE and to the thresholds, and no
# criterion is within 3 MCSE of its threshold.
FakeSummaries <- function() {
  d <- PilotDesign()
  s <- rbind(cbind(d, estimator = "empirical", stringsAsFactors = FALSE),
             cbind(d, estimator = "kernel", stringsAsFactors = FALSE))
  s$gap <- 0.02
  s$gap_mcse <- 0.001
  s$gap_n_nonzero <- 0L
  s$rmse_ratio <- 1.3
  s$rmse_ratio_mcse <- 0.02
  s$bias_j_ratio <- 0.33
  s$bias_j_ratio_mcse <- 0.02
  s$bias_j_p1 <- 0.01
  s$bias_j_p1_mcse <- 0.001
  s$bias_j_p2 <- 0.03
  s$bias_j_p2_mcse <- 0.001
  s$cor_b_gap <- 0.8
  s$cor_b_gap_mcse <- 0.02
  s$gap_ratio <- 1
  s$gap_ratio_mcse <- 0.05
  s$cover_mid <- 0.95
  s$cover_mid_mcse <- 0.005
  s$gap[s$miss_rate == 0] <- 0
  s$gap[s$miss_rate == 0.6] <- 0.05
  rownames(s) <- NULL
  s
}

test_that("a clear pass gives 'piloted-pass'", {
  res <- ApplyPassRule(FakeSummaries())
  expect_identical(res$status, "piloted-pass")
  expect_named(res, c("criteria", "questions", "status", "largest_gap"))
  expect_equal(res$questions$question, c("Q1", "Q2", "Q3"))
  expect_true(all(res$questions$passed))
  expect_false(any(res$questions$near))
  expect_named(res$criteria, c("question", "clause", "cell", "measure",
                               "estimate", "mcse", "rule", "met", "near"))
  expect_true(all(res$criteria$met))
  expect_false(any(res$criteria$near))
})

test_that("the criteria table has one row per criterion of the rule", {
  res <- ApplyPassRule(FakeSummaries())
  counts <- table(res$criteria$question)
  # Q1: a, b. Q2: a (two estimators), b (two), c (every PMM cell with
  # missing values: 10 data cells x 2 estimators). Q3: six.
  expect_equal(unname(counts[["Q1"]]), 2L)
  expect_equal(unname(counts[["Q2"]]), 2L + 2L + 20L)
  expect_equal(unname(counts[["Q3"]]), 6L)
  q2c <- res$criteria[res$criteria$question == "Q2" &
                        res$criteria$clause == "c", ]
  expect_equal(nrow(q2c), 20L)
  expect_true(all(grepl("PMM", q2c$cell)))
  expect_false(any(grepl("NN|nn,", q2c$cell)))
})

test_that("a nonzero gap in the null cell gives 'piloted-fail'", {
  s <- FakeSummaries()
  null <- CellRows(s, miss = 0, engine = "none", est = "empirical")
  expect_equal(sum(null), 1L)
  s$gap_n_nonzero[null] <- 3L
  res <- ApplyPassRule(s)
  expect_identical(res$status, "piloted-fail")
  expect_false(res$questions$passed[res$questions$question == "Q1"])
  q1b <- res$criteria[res$criteria$question == "Q1" &
                        res$criteria$clause == "b", ]
  expect_equal(q1b$estimate, 3)
  expect_false(q1b$met)
  expect_false(q1b$near)
})

test_that("a base gap within 3 MCSE of zero fails Q1 and the pilot", {
  s <- FakeSummaries()
  s$gap[CellRows(s, est = "empirical")] <- 0.002
  res <- ApplyPassRule(s)
  expect_false(res$questions$passed[1])
  expect_identical(res$status, "piloted-fail")
})

test_that("base gap 0.004 with everything else passing is a close call", {
  s <- FakeSummaries()
  base <- CellRows(s, est = "empirical")
  s$gap[base] <- 0.004
  s$gap_mcse[base] <- 0.001
  res <- ApplyPassRule(s)
  # 0.004 > 3 * 0.001 so Q1 passes, but only 0.001 above the threshold,
  # within 3 MCSE.
  expect_true(res$questions$passed[res$questions$question == "Q1"])
  expect_true(res$questions$near[res$questions$question == "Q1"])
  # The kernel twin still carries Q2.
  expect_true(res$questions$passed[res$questions$question == "Q2"])
  expect_true(res$questions$passed[res$questions$question == "Q3"])
  expect_identical(res$status, "piloted-close-call")
})

test_that("Q3 coverage of 0.80 gives 'piloted-fail'", {
  s <- FakeSummaries()
  s$cover_mid[CellRows(s, est = "kernel")] <- 0.80
  res <- ApplyPassRule(s)
  expect_true(res$questions$passed[1])
  expect_false(res$questions$passed[res$questions$question == "Q3"])
  expect_false(res$questions$near[res$questions$question == "Q3"])
  expect_identical(res$status, "piloted-fail")
  cov <- res$criteria[grepl("coverage", res$criteria$measure), ]
  expect_equal(cov$estimate, 0.80)
  expect_false(cov$met)
})

test_that("Q3 coverage just below 0.92 is a close call, not a fail", {
  s <- FakeSummaries()
  s$cover_mid[CellRows(s, est = "kernel")] <- 0.915
  res <- ApplyPassRule(s)
  expect_false(res$questions$passed[res$questions$question == "Q3"])
  expect_true(res$questions$near[res$questions$question == "Q3"])
  expect_identical(res$status, "piloted-close-call")
})

test_that("coverage at 0.98 passes and above it fails (boundaries)", {
  s <- FakeSummaries()
  kernel_base <- CellRows(s, est = "kernel")
  s$cover_mid[kernel_base] <- 0.98
  expect_true(ApplyPassRule(s)$questions$passed[3])
  s$cover_mid[kernel_base] <- 0.99
  expect_false(ApplyPassRule(s)$questions$passed[3])
})

test_that("Q2 failing while Q1 and Q3 pass is a close call", {
  s <- FakeSummaries()
  pmm_missing <- s$engine == "pmm" & s$miss_rate > 0
  # Small gaps, tiny MCSE: Q1 still passes (0.002 > 3 * 0.0001), no gap
  # reaches 0.01 or 0.02, and no RMSE ratio leaves [0.90, 1.10].
  s$gap[pmm_missing] <- 0.002
  s$gap_mcse[pmm_missing] <- 0.0001
  s$rmse_ratio[pmm_missing] <- 1.0
  s$rmse_ratio_mcse[pmm_missing] <- 0.01
  res <- ApplyPassRule(s)
  expect_equal(res$questions$passed, c(TRUE, FALSE, TRUE), ignore_attr = TRUE)
  expect_identical(res$status, "piloted-close-call")
  # And the report can say which kind of close call it is.
  expect_true(res$largest_gap$all_below_0005)
  expect_equal(res$largest_gap$gap, 0.002)
})

test_that("Q2 met through the RMSE clause alone: near iff all met are", {
  s <- FakeSummaries()
  pmm_missing <- s$engine == "pmm" & s$miss_rate > 0
  s$gap[pmm_missing] <- 0.002
  s$gap_mcse[pmm_missing] <- 0.0001
  # Every RMSE ratio is met but within 3 MCSE of 1.10.
  s$rmse_ratio[pmm_missing] <- 1.12
  s$rmse_ratio_mcse[pmm_missing] <- 0.02
  res <- ApplyPassRule(s)
  expect_true(res$questions$passed[2])
  expect_true(res$questions$near[2])
  expect_identical(res$status, "piloted-close-call")
  # One clearly-met clause makes the rule not near: it passes cleanly.
  s$rmse_ratio[which(pmm_missing)[1]] <- 1.6
  res2 <- ApplyPassRule(s)
  expect_true(res2$questions$passed[2])
  expect_false(res2$questions$near[2])
  expect_identical(res2$status, "piloted-pass")
})

test_that("a Q3 clause near its threshold makes a passing Q3 'near'", {
  s <- FakeSummaries()
  s$bias_j_ratio[CellRows(s, est = "empirical")] <- 0.48
  res <- ApplyPassRule(s)
  expect_true(res$questions$passed[3])
  expect_true(res$questions$near[3])
  expect_identical(res$status, "piloted-close-call")
})

test_that("a criterion within 3 MCSE of its threshold is marked near", {
  s <- FakeSummaries()
  s$gap[CellRows(s, miss = 0.6, est = "empirical")] <- 0.022
  res <- ApplyPassRule(s)
  q2b <- res$criteria[res$criteria$question == "Q2" &
                        res$criteria$clause == "b", ]
  # 0.022 is 0.002 above 0.02, within 3 * 0.001; the kernel row is not.
  expect_equal(q2b$near, c(TRUE, FALSE))
  expect_equal(q2b$met, c(TRUE, TRUE))
})

test_that("largest_gap reports the largest PMM gap with a missing fraction", {
  s <- FakeSummaries()
  target <- CellRows(s, shape = "flat", miss = 0.6, n = 1000, est = "kernel")
  expect_equal(sum(target), 1L)
  s$gap[target] <- 0.06
  # A larger gap in a nearest-neighbour cell decides nothing.
  s$gap[s$engine == "nn"][1] <- 0.5
  res <- ApplyPassRule(s)
  expect_equal(res$largest_gap$gap, 0.06)
  expect_equal(res$largest_gap$gap_mcse, 0.001)
  expect_identical(res$largest_gap$cell,
                   "flat, 60%, 1000, PMM, L = 20, kernel")
  expect_false(res$largest_gap$all_below_0005)
})

test_that("ApplyPassRule needs the base, kernel twin, null and 60% cells", {
  s <- FakeSummaries()
  expect_error(ApplyPassRule(s[!CellRows(s, est = "empirical"), ]))
  expect_error(ApplyPassRule(s[!CellRows(s, est = "kernel"), ]))
  expect_error(ApplyPassRule(s[!CellRows(s, miss = 0, engine = "none"), ]))
  expect_error(ApplyPassRule(s[!CellRows(s, miss = 0.6), ]))
})

test_that("Criterion builds one row and flags nearness at 3 MCSE", {
  cr <- micutoff:::Criterion("Q1", "a", "base", "mean gap", 0.02, 0.001,
                             "> 3 MCSE", TRUE, 0.017)
  expect_s3_class(cr, "data.frame")
  expect_equal(nrow(cr), 1L)
  expect_named(cr, c("question", "clause", "cell", "measure", "estimate",
                     "mcse", "rule", "met", "near"))
  expect_identical(cr$question, "Q1")
  expect_identical(cr$cell, "base")
  expect_true(cr$met)
  expect_false(cr$near)
  near <- micutoff:::Criterion("Q1", "a", "base", "mean gap", 0.02, 0.001,
                               "> 3 MCSE", TRUE, 0.0029)
  expect_true(near$near)
  # Strictly less than 3 MCSE.
  edge <- micutoff:::Criterion("Q1", "a", "base", "mean gap", 0.02, 0.001,
                               "> 3 MCSE", TRUE, 0.003)
  expect_false(edge$near)
})

test_that("Criterion is never near when the MCSE is NA", {
  cr <- micutoff:::Criterion("Q1", "b", "null", "nonzero gaps", 0, NA, "= 0",
                             TRUE, NA)
  expect_false(cr$near)
  expect_true(is.na(cr$mcse))
  expect_type(cr$cell, "character")
})

test_that("RuleNear for a rule that needs all its clauses", {
  # All met: near if any clause is near.
  all_met <- data.frame(met = c(TRUE, TRUE, TRUE),
                        near = c(FALSE, TRUE, FALSE))
  expect_true(micutoff:::RuleNear(all_met, TRUE))
  all_met$near <- c(FALSE, FALSE, FALSE)
  expect_false(micutoff:::RuleNear(all_met, TRUE))
  # Not all met: near only if every failed clause is near.
  failed <- data.frame(met = c(TRUE, FALSE, FALSE),
                       near = c(FALSE, TRUE, TRUE))
  expect_true(micutoff:::RuleNear(failed, TRUE))
  failed$near[3] <- FALSE
  expect_false(micutoff:::RuleNear(failed, TRUE))
})

test_that("RuleNear for a rule met through any one clause", {
  # Some met: near only if every met clause is near.
  some_met <- data.frame(met = c(TRUE, FALSE, TRUE),
                         near = c(TRUE, FALSE, TRUE))
  expect_true(micutoff:::RuleNear(some_met, FALSE))
  some_met$near[3] <- FALSE
  expect_false(micutoff:::RuleNear(some_met, FALSE))
  # None met: near if any clause is near.
  none_met <- data.frame(met = c(FALSE, FALSE), near = c(FALSE, TRUE))
  expect_true(micutoff:::RuleNear(none_met, FALSE))
  none_met$near <- c(FALSE, FALSE)
  expect_false(micutoff:::RuleNear(none_met, FALSE))
})
