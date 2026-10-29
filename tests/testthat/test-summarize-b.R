# Tests for R/summarize_b.R: the re-pilot's per-cell summaries and its
# pre-registered pass rule (pilot-b/preregistration.md, sections 3 and 5).

# Four replicates with hand-chosen values, one column per column that
# RunReplicateB() returns. Optimism (apparent - j_at_c_hat) is
# 0.04, 0.05, 0.03, 0.04; the corrected index's error against J(c_hat) is
# 0, 0, -0.01, -0.03.
FakeReps <- function() {
  data.frame(
    c_hat = c(1.1, 0.9, 1.2, 1.0),
    apparent = c(0.70, 0.72, 0.74, 0.76),
    apparent_at_c_hat = c(0.70, 0.72, 0.74, 0.76),
    j_at_c_hat = c(0.66, 0.67, 0.71, 0.72),
    corrected = c(0.66, 0.67, 0.70, 0.69),
    mean_optimism = c(0.04, 0.05, 0.04, 0.06),
    c_p2 = c(1.0, 1.0, 1.1, 1.0),
    gap = c(0, 0.01, 0.02, 0),
    b_c = c(0, 0.1, 0.2, 0),
    pred_gap = c(0, 0.002, 0.004, 0.002),
    cover_pointwise = c(TRUE, FALSE, FALSE, FALSE),
    cover_rubin = c(TRUE, TRUE, TRUE, FALSE),
    cover_boot = rep(TRUE, 4),
    width_pointwise = c(0.05, 0.06, 0.07, 0.08),
    width_rubin = c(0.09, 0.10, 0.11, 0.12),
    width_boot = c(0.10, 0.12, 0.14, 0.16),
    q_rubin = c(2.5, 2.6, 2.7, 2.8),
    q_boot = c(2.9, 3.0, 3.1, 3.2),
    set_rubin_contains = c(TRUE, TRUE, FALSE, TRUE),
    set_rubin_length = c(0.2, 0.3, 0.4, 0.5),
    set_boot_contains = rep(TRUE, 4),
    set_boot_length = c(0.3, 0.4, 0.5, 0.6),
    cover_star = c(TRUE, TRUE, TRUE, FALSE),
    grid_lo = c(0.2, 0.2, 0.2, 1.5),
    grid_hi = rep(2, 4),
    k_mid = 1:4,
    miss_frac = c(0.38, 0.40, 0.42, 0.40))
}

fake_truth <- list(c_star = 1, j_star = 0.7)

# The columns SummarizeCellB() returns.
summary_columns <- c(
  "n_rep", "miss_frac", "optimism", "optimism_mcse", "apparent_bias_star",
  "apparent_bias_star_mcse", "corrected_bias", "corrected_bias_mcse",
  "corrected_bias_star", "corrected_bias_star_mcse", "bias_ratio",
  "bias_ratio_mcse", "mean_boot_optimism", "cover_pointwise",
  "cover_pointwise_mcse", "width_pointwise", "cover_rubin",
  "cover_rubin_mcse", "width_rubin", "cover_boot", "cover_boot_mcse",
  "width_boot", "set_rubin", "set_rubin_mcse", "set_rubin_length",
  "set_boot", "set_boot_mcse", "set_boot_length", "cover_star",
  "cover_star_mcse", "q_rubin", "q_boot", "gap", "gap_mcse",
  "gap_n_nonzero", "pred_gap", "rmse_c_p1", "rmse_c_p2", "rmse_ratio",
  "rmse_ratio_mcse", "grid_lo", "grid_hi", "c_star_in_grid")

# -- SummarizeCellB -----------------------------------------------------

test_that("SummarizeCellB returns one row with every measure", {
  out <- SummarizeCellB(FakeReps(), fake_truth)
  expect_s3_class(out, "data.frame")
  expect_equal(nrow(out), 1L)
  expect_named(out, summary_columns)
  expect_equal(out$n_rep, 4)
  expect_equal(out$miss_frac, 0.4)
})

test_that("SummarizeCellB's optimism and bias are the known means", {
  reps <- FakeReps()
  out <- SummarizeCellB(reps, fake_truth)
  # Hand values.
  expect_equal(out$optimism, 0.04)
  expect_equal(out$apparent_bias_star, 0.03)
  expect_equal(out$corrected_bias, -0.01)
  expect_equal(out$corrected_bias_star, -0.02)
  expect_equal(out$bias_ratio, -0.25)
  expect_equal(out$mean_boot_optimism, 0.0475)
  # MCSEs are sd / sqrt(R) of the per-replicate values.
  opt <- reps$apparent - reps$j_at_c_hat
  cor_err <- reps$corrected - reps$j_at_c_hat
  expect_equal(out$optimism_mcse, sd(opt) / 2)
  expect_equal(out$apparent_bias_star_mcse, sd(reps$apparent) / 2)
  expect_equal(out$corrected_bias_mcse, sd(cor_err) / 2)
  expect_equal(out$corrected_bias_star_mcse, sd(reps$corrected) / 2)
  expect_gt(out$optimism_mcse, 0)
  # Delta-method MCSE of the ratio of means, from the residual form.
  r <- mean(cor_err) / mean(opt)
  expect_equal(out$bias_ratio_mcse,
               sd(cor_err - r * opt) / (2 * abs(mean(opt))))
})

test_that("SummarizeCellB's coverage, set, and width summaries are means", {
  out <- SummarizeCellB(FakeReps(), fake_truth)
  expect_equal(out$cover_pointwise, 0.25)
  expect_equal(out$cover_rubin, 0.75)
  expect_equal(out$cover_boot, 1)
  expect_equal(out$set_rubin, 0.75)
  expect_equal(out$set_boot, 1)
  expect_equal(out$cover_star, 0.75)
  # Binomial MCSE sqrt(p (1 - p) / R); zero when every replicate covers.
  expect_equal(out$cover_pointwise_mcse, sqrt(0.25 * 0.75 / 4))
  expect_equal(out$cover_rubin_mcse, sqrt(0.75 * 0.25 / 4))
  expect_equal(out$cover_boot_mcse, 0)
  expect_equal(out$set_rubin_mcse, sqrt(0.75 * 0.25 / 4))
  expect_equal(out$set_boot_mcse, 0)
  expect_equal(out$cover_star_mcse, sqrt(0.75 * 0.25 / 4))
  expect_equal(out$width_pointwise, 0.065)
  expect_equal(out$width_rubin, 0.105)
  expect_equal(out$width_boot, 0.13)
  expect_equal(out$set_rubin_length, 0.35)
  expect_equal(out$set_boot_length, 0.45)
  expect_equal(out$q_rubin, 2.65)
  expect_equal(out$q_boot, 3.05)
})

test_that("SummarizeCellB summarizes the gap and the cutoff's error", {
  out <- SummarizeCellB(FakeReps(), fake_truth)
  gap <- c(0, 0.01, 0.02, 0)
  expect_equal(out$gap, 0.0075)
  expect_equal(out$gap_mcse, sd(gap) / 2)
  expect_equal(out$gap_n_nonzero, 2)
  expect_equal(out$pred_gap, 0.002)
  # c_hat errors against c* = 1: 0.1, -0.1, 0.2, 0; c_p2 errors: 0, 0, 0.1,
  # 0.
  expect_equal(out$rmse_c_p1, sqrt(mean(c(0.01, 0.01, 0.04, 0))))
  expect_equal(out$rmse_c_p2, sqrt(0.01 / 4))
  sq1 <- c(0.01, 0.01, 0.04, 0)
  sq2 <- c(0, 0, 0.01, 0)
  expect_equal(out$rmse_ratio, sqrt(mean(sq2) / mean(sq1)))
  # The ratio of squared errors' MCSE (residual form), then the delta
  # method for the square root.
  r <- mean(sq2) / mean(sq1)
  mcse_r <- sd(sq2 - r * sq1) / (2 * mean(sq1))
  expect_equal(out$rmse_ratio_mcse, mcse_r / (2 * sqrt(r)))
})

test_that("SummarizeCellB reports the grid and whether it holds c*", {
  out <- SummarizeCellB(FakeReps(), fake_truth)
  expect_equal(out$grid_lo, mean(c(0.2, 0.2, 0.2, 1.5)))
  expect_equal(out$grid_hi, 2)
  # c* = 1 is inside the grid in the first three replicates only.
  expect_equal(out$c_star_in_grid, 0.75)
  moved <- SummarizeCellB(FakeReps(), list(c_star = 1.8, j_star = 0.7))
  expect_equal(moved$c_star_in_grid, 1)
  expect_equal(moved$rmse_c_p1,
               sqrt(mean((c(1.1, 0.9, 1.2, 1.0) - 1.8)^2)))
  outside <- SummarizeCellB(FakeReps(), list(c_star = 5, j_star = 0.7))
  expect_equal(outside$c_star_in_grid, 0)
})

test_that("SummarizeCellB uses the truth's J* for the biases against J*", {
  low <- SummarizeCellB(FakeReps(), list(c_star = 1, j_star = 0.6))
  expect_equal(low$apparent_bias_star, 0.13)
  expect_equal(low$corrected_bias_star, 0.08)
  # The biases against J(c_hat) do not involve J*.
  expect_equal(low$optimism, 0.04)
  expect_equal(low$corrected_bias, -0.01)
})

test_that("SummarizeCellB ignores the labelling columns of RunDataCell", {
  reps <- FakeReps()
  labelled <- cbind(reps, rep = 1:4, cell = 2L)
  expect_equal(SummarizeCellB(labelled, fake_truth),
               SummarizeCellB(reps, fake_truth))
})

test_that("SummarizeCellB summarizes real replicates of a small cell", {
  cell <- PilotDesignB()[2, ]
  cell$n <- 40L
  cell$n_imp <- 3L
  truth <- MarkerTruth(cell$delta, cell$sigma1)
  old <- RNGkind()
  on.exit(RNGkind(old[1], old[2], old[3]))
  reps <- RunDataCell(cell, 3, replicate_fun = function(cell, truth) {
    RunReplicateB(cell, truth, n_boot = 10L, m_boot = 2L, grid_n = 9L,
                  n_draw = 500L)
  })
  # The hand-made replicates have the same columns as the real ones.
  expect_setequal(names(FakeReps()), setdiff(names(reps), c("rep", "cell")))
  out <- SummarizeCellB(reps, truth)
  expect_equal(nrow(out), 1L)
  expect_named(out, summary_columns)
  expect_equal(out$n_rep, 3)
  expect_true(all(is.finite(unlist(out[c("optimism", "optimism_mcse",
                                         "cover_boot", "set_boot",
                                         "rmse_c_p1", "gap",
                                         "c_star_in_grid")]))))
  expect_equal(out$optimism, mean(reps$apparent - reps$j_at_c_hat))
})

# -- SummarizeAllCellsB -------------------------------------------------

test_that("SummarizeAllCellsB returns one row per cell, in cell order", {
  design <- PilotDesignB()
  r1 <- FakeReps()
  r1$cell <- 1L
  r6 <- FakeReps()
  r6$apparent <- r6$apparent + 0.05
  r6$cell <- 6L
  r2 <- FakeReps()
  r2$cell <- 2L
  out <- SummarizeAllCellsB(rbind(r6, r1, r2), design)
  expect_equal(nrow(out), 3L)
  expect_equal(out$cell, c(1L, 2L, 6L))
  expect_equal(rownames(out), as.character(1:3))
  # The design columns, the truth, and the measures.
  expect_true(all(names(design) %in% names(out)))
  expect_true(all(c("c_star", "j_star", "kappa") %in% names(out)))
  expect_true(all(summary_columns %in% names(out)))
  expect_equal(out$shape, c("sharp", "sharp", "flat"))
  expect_equal(out[, names(design)], design[c(1, 2, 6), ],
               ignore_attr = TRUE)
})

test_that("SummarizeAllCellsB gives each cell its own truth and summary", {
  design <- PilotDesignB()
  r2 <- FakeReps()
  r2$cell <- 2L
  r7 <- FakeReps()
  r7$apparent <- r7$apparent + 0.05
  r7$cell <- 7L
  out <- SummarizeAllCellsB(rbind(r2, r7), design)
  for (i in 1:2) {
    k <- out$cell[i]
    row <- design[design$cell == k, ]
    truth <- MarkerTruth(row$delta, row$sigma1)
    expect_equal(out$c_star[i], truth$c_star)
    expect_equal(out$j_star[i], truth$j_star)
    expect_equal(out$kappa[i], truth$kappa)
    reps <- list(r2, r7)[[i]]
    expected <- SummarizeCellB(reps, truth)
    expect_equal(as.list(out[i, names(expected)]), as.list(expected))
  }
  # The two cells differ in shape, so in c* and J*, and cell 7 has the
  # larger optimism by construction.
  expect_false(out$c_star[1] == out$c_star[2])
  expect_equal(out$optimism[2] - out$optimism[1], 0.05)
})

test_that("SummarizeAllCellsB covers the whole design", {
  design <- PilotDesignB()
  reps <- do.call(rbind, lapply(design$cell, function(k) {
    r <- FakeReps()
    r$cell <- k
    r
  }))
  out <- SummarizeAllCellsB(reps, design)
  expect_equal(nrow(out), 10L)
  expect_equal(out$cell, 1:10)
  expect_equal(out$n_rep, rep(4, 10))
})

# -- ApplyPassRuleB -----------------------------------------------------

# Summaries of the 10 cells with columns as SummarizeAllCellsB returns them
# (the ones the pass rule reads): a clear pass, no criterion within 3 MCSE
# of its threshold.
FakeSummariesB <- function() {
  s <- PilotDesignB()
  s$optimism <- 0.03
  s$optimism_mcse <- 0.003
  s$cover_pointwise <- 0.70
  s$cover_pointwise_mcse <- 0.02
  s$bias_ratio <- 0.2
  s$bias_ratio_mcse <- 0.05
  s$cover_boot <- 0.95
  s$cover_boot_mcse <- 0.005
  s$set_boot <- 0.97
  s$set_boot_mcse <- 0.005
  s
}

# Logical index of a sharp cell.
SharpCell <- function(s, miss, engine) {
  s$shape == "sharp" & s$miss_rate == miss & s$engine == engine
}

# The criterion row of a question and clause whose cell label matches.
Crit <- function(out, question, clause, pattern) {
  crit <- out$criteria
  crit[crit$question == question & crit$clause == clause &
         grepl(pattern, crit$cell, fixed = TRUE), ]
}

test_that("a clear pass is piloted-pass, with 9 criteria all met", {
  out <- ApplyPassRuleB(FakeSummariesB())
  expect_named(out, c("criteria", "questions", "status"))
  expect_equal(out$status, "piloted-pass")
  expect_equal(out$questions$question, c("Q1", "Q2", "Q3"))
  expect_true(all(out$questions$passed))
  expect_false(any(out$questions$near))
  expect_equal(nrow(out$criteria), 9L)
  expect_equal(as.vector(table(out$criteria$question)), c(2L, 2L, 5L))
  expect_true(all(out$criteria$met))
  expect_false(any(out$criteria$near))
  expect_named(out$criteria, c("question", "clause", "cell", "measure",
                               "estimate", "mcse", "rule", "met", "near"))
})

test_that("the criteria carry the estimates the rule reads", {
  s <- FakeSummariesB()
  s$bias_ratio[SharpCell(s, 0.4, "pmm")] <- -0.3
  out <- ApplyPassRuleB(s)
  expect_equal(Crit(out, "Q1", "a", "base")$estimate, 0.03)
  expect_equal(Crit(out, "Q1", "b", "base")$estimate, 0.70)
  expect_equal(Crit(out, "Q2", "a", "60%")$estimate, 0.03)
  # The ratio is judged in absolute value.
  q3a <- Crit(out, "Q3", "a", "base")
  expect_equal(q3a$estimate, 0.3)
  expect_true(q3a$met)
  expect_equal(Crit(out, "Q3", "b", "normal twin")$estimate, 0.95)
  expect_equal(Crit(out, "Q3", "c", "normal twin")$estimate, 0.97)
  expect_equal(out$status, "piloted-pass")
})

test_that("optimism not beyond 3 MCSE is piloted-fail", {
  s <- FakeSummariesB()
  # 3 MCSE = 0.012; the optimism 0.008 is below it.
  s$optimism[SharpCell(s, 0.4, "pmm")] <- 0.008
  s$optimism_mcse[SharpCell(s, 0.4, "pmm")] <- 0.004
  out <- ApplyPassRuleB(s)
  expect_equal(out$status, "piloted-fail")
  expect_false(out$questions$passed[out$questions$question == "Q1"])
  expect_false(Crit(out, "Q1", "a", "base")$met)
})

test_that("pointwise coverage of 0.90 or more fails Q1", {
  base <- SharpCell(FakeSummariesB(), 0.4, "pmm")
  for (cover in c(0.90, 0.92, 0.95)) {
    s <- FakeSummariesB()
    s$cover_pointwise[base] <- cover
    out <- ApplyPassRuleB(s)
    expect_equal(out$status, "piloted-fail")
    expect_false(Crit(out, "Q1", "b", "base")$met)
    expect_true(Crit(out, "Q1", "a", "base")$met)
  }
  # Just below 0.90 is a pass of the clause (and near the threshold).
  s <- FakeSummariesB()
  s$cover_pointwise[base] <- 0.89
  expect_true(Crit(ApplyPassRuleB(s), "Q1", "b", "base")$met)
})

test_that("base bootstrap coverage of 0.80 is piloted-fail", {
  s <- FakeSummariesB()
  s$cover_boot[SharpCell(s, 0.4, "pmm")] <- 0.80
  s$cover_boot_mcse[SharpCell(s, 0.4, "pmm")] <- 0.01
  out <- ApplyPassRuleB(s)
  expect_equal(out$status, "piloted-fail")
  q3 <- out$questions[out$questions$question == "Q3", ]
  expect_false(q3$passed)
  expect_false(q3$near)
  expect_true(out$questions$passed[1])
  expect_false(Crit(out, "Q3", "b", "base (")$met)
  expect_true(Crit(out, "Q3", "b", "normal twin")$met)
})

test_that("coverage above 0.98 also fails the interval", {
  s <- FakeSummariesB()
  s$cover_boot[SharpCell(s, 0.4, "pmm")] <- 1
  out <- ApplyPassRuleB(s)
  expect_false(Crit(out, "Q3", "b", "base (")$met)
  expect_equal(out$status, "piloted-fail")
})

test_that("coverage 0.925 (MCSE 0.012), all else passing, is a close call", {
  s <- FakeSummariesB()
  s$cover_boot[SharpCell(s, 0.4, "pmm")] <- 0.925
  s$cover_boot_mcse[SharpCell(s, 0.4, "pmm")] <- 0.012
  out <- ApplyPassRuleB(s)
  expect_equal(out$status, "piloted-close-call")
  q3 <- out$questions[out$questions$question == "Q3", ]
  expect_true(q3$passed)
  expect_true(q3$near)
  expect_true(Crit(out, "Q3", "b", "base (")$near)
  expect_true(all(out$questions$passed))
})

test_that("a coverage that just fails but is near is a close call", {
  s <- FakeSummariesB()
  s$cover_boot[SharpCell(s, 0.4, "pmm")] <- 0.91
  s$cover_boot_mcse[SharpCell(s, 0.4, "pmm")] <- 0.01
  out <- ApplyPassRuleB(s)
  q3 <- out$questions[out$questions$question == "Q3", ]
  expect_false(q3$passed)
  expect_true(q3$near)
  expect_equal(out$status, "piloted-close-call")
})

test_that("the normal twin is judged as well as the base cell", {
  s <- FakeSummariesB()
  twin <- SharpCell(s, 0.4, "norm")
  s$cover_boot[twin] <- 0.85
  out <- ApplyPassRuleB(s)
  expect_equal(out$status, "piloted-fail")
  expect_false(Crit(out, "Q3", "b", "normal twin")$met)
  s2 <- FakeSummariesB()
  s2$set_boot[SharpCell(s2, 0.4, "norm")] <- 0.80
  out2 <- ApplyPassRuleB(s2)
  expect_equal(out2$status, "piloted-fail")
  expect_false(Crit(out2, "Q3", "c", "normal twin")$met)
  expect_true(Crit(out2, "Q3", "c", "base (")$met)
})

test_that("a bias ratio beyond 0.5 in absolute value fails Q3", {
  s <- FakeSummariesB()
  s$bias_ratio[SharpCell(s, 0.4, "pmm")] <- 0.8
  expect_equal(ApplyPassRuleB(s)$status, "piloted-fail")
  s$bias_ratio[SharpCell(s, 0.4, "pmm")] <- -0.8
  expect_equal(ApplyPassRuleB(s)$status, "piloted-fail")
})

test_that("Q2 passes through either the base or the 60% cell", {
  s <- FakeSummariesB()
  base <- SharpCell(s, 0.4, "pmm")
  sixty <- SharpCell(s, 0.6, "pmm")
  s$optimism[base] <- 0.006
  s$optimism_mcse[base] <- 0.0005
  out <- ApplyPassRuleB(s)
  q2 <- out$questions[out$questions$question == "Q2", ]
  expect_true(q2$passed)
  expect_false(Crit(out, "Q2", "a", "base")$met)
  expect_true(Crit(out, "Q2", "a", "60%")$met)
  expect_equal(out$status, "piloted-pass")
  # Neither reaches 0.01: Q2 fails, which cannot be a pass.
  s$optimism[sixty] <- 0.004
  s$optimism_mcse[sixty] <- 0.0005
  out2 <- ApplyPassRuleB(s)
  expect_false(out2$questions$passed[out2$questions$question == "Q2"])
  expect_true(out2$questions$passed[out2$questions$question == "Q1"])
  expect_equal(out2$status, "piloted-close-call")
})

test_that("a Q1 pass within 3 MCSE of its threshold is a close call", {
  s <- FakeSummariesB()
  base <- SharpCell(s, 0.4, "pmm")
  # 3 MCSE = 0.009; the optimism 0.0095 is just beyond it.
  s$optimism[base] <- 0.0095
  s$optimism_mcse[base] <- 0.003
  out <- ApplyPassRuleB(s)
  q1 <- out$questions[out$questions$question == "Q1", ]
  expect_true(q1$passed)
  expect_true(q1$near)
  expect_equal(out$status, "piloted-close-call")
})

test_that("only the sharp base, twin, and 60% cells are read", {
  s <- FakeSummariesB()
  read <- SharpCell(s, 0.4, "pmm") | SharpCell(s, 0.4, "norm") |
    SharpCell(s, 0.6, "pmm")
  expect_equal(sum(read), 3L)
  s$optimism[!read] <- 0
  s$cover_pointwise[!read] <- 0.99
  s$bias_ratio[!read] <- 5
  s$cover_boot[!read] <- 0.1
  s$set_boot[!read] <- 0.1
  out <- ApplyPassRuleB(s)
  expect_equal(out$status, "piloted-pass")
  expect_equal(out$criteria, ApplyPassRuleB(FakeSummariesB())$criteria)
})

test_that("a design with a repeated cell is refused", {
  s <- FakeSummariesB()
  dup <- rbind(s, s[SharpCell(s, 0.4, "pmm"), ])
  expect_error(ApplyPassRuleB(dup))
  missing_cell <- s[!SharpCell(s, 0.6, "pmm"), ]
  expect_error(ApplyPassRuleB(missing_cell))
})
