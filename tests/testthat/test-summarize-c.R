# Tests for R/summarize_c.R: pilot-c's per-cell summaries and its
# pre-registered pass rule (pilot-c/preregistration.md, sections 3 and 5).

# Four replicates with hand-chosen values, one column per column that
# RunReplicateC() returns. Optimism (apparent - j_at_c_hat) is
# 0.04, 0.05, 0.03, 0.04; the 20-imputation corrected index's error against
# J(c_hat) is 0, 0, -0.01, -0.03 and the 2-imputation one's is
# 0.01, 0.01, 0.01, 0.03.
FakeRepsC <- function() {
  data.frame(
    c_hat = c(1.1, 0.9, 1.2, 1.0),
    apparent = c(0.70, 0.72, 0.74, 0.76),
    apparent_at_c_hat = c(0.70, 0.72, 0.74, 0.76),
    j_at_c_hat = c(0.66, 0.67, 0.71, 0.72),
    corrected_20 = c(0.66, 0.67, 0.70, 0.69),
    optimism_20 = c(0.04, 0.05, 0.04, 0.06),
    corrected_2 = c(0.67, 0.68, 0.72, 0.75),
    optimism_2 = c(0.03, 0.04, 0.02, 0.01),
    c_p2 = c(1.0, 1.0, 1.1, 1.0),
    gap = c(0, 0.01, 0.02, 0),
    cover_pointwise = c(TRUE, FALSE, FALSE, FALSE),
    cover_rubin = c(TRUE, TRUE, TRUE, FALSE),
    width_pointwise = c(0.05, 0.06, 0.07, 0.08),
    width_rubin = c(0.09, 0.10, 0.11, 0.12),
    q_rubin = c(2.5, 2.6, 2.7, 2.8),
    q_boot = c(2.9, 3.0, 3.1, 3.2),
    q_hybrid = c(2.7, 2.8, 2.9, 3.0),
    cover_boot = rep(TRUE, 4),
    width_boot = c(0.10, 0.12, 0.14, 0.16),
    bandset_boot_contains = c(TRUE, TRUE, TRUE, FALSE),
    bandset_boot_length = c(0.4, 0.5, 0.4, 0.5),
    compset_boot_contains = c(TRUE, TRUE, FALSE, FALSE),
    compset_boot_length = c(0.1, 0.2, 0.3, 0.2),
    q_comp_boot = c(2.0, 2.1, 2.2, 2.3),
    cover_hybrid = c(TRUE, TRUE, FALSE, TRUE),
    width_hybrid = c(0.11, 0.13, 0.15, 0.17),
    bandset_hybrid_contains = rep(TRUE, 4),
    bandset_hybrid_length = rep(0.3, 4),
    compset_hybrid_contains = c(TRUE, TRUE, TRUE, FALSE),
    compset_hybrid_length = c(0.1, 0.1, 0.2, 0.2),
    q_comp_hybrid = c(1.9, 2.0, 2.1, 2.2),
    c_star_in_grid = c(TRUE, TRUE, TRUE, FALSE),
    grid_lo = c(0.2, 0.2, 0.2, 1.5),
    grid_hi = rep(2, 4),
    miss_frac = c(0.38, 0.40, 0.42, 0.40))
}

# The truth the hand values refer to: c* and J* are chosen to fit them;
# delta and sigma1 feed the near-optimal region's length.
fake_truth_c <- list(delta = 2, sigma1 = 1, c_star = 1, j_star = 0.7)

# The columns SummarizeCellC() returns, in order.
summary_columns_c <- c(
  "n_rep", "miss_frac", "optimism", "optimism_mcse", "apparent_bias_star",
  "apparent_bias_star_mcse", "corrected_bias_20", "corrected_bias_20_mcse",
  "correction_20", "bias_ratio_20", "bias_ratio_20_mcse",
  "corrected_bias_2", "corrected_bias_2_mcse", "correction_2",
  "bias_ratio_2", "bias_ratio_2_mcse", "cover_pointwise",
  "cover_pointwise_mcse", "width_pointwise", "cover_rubin",
  "cover_rubin_mcse", "width_rubin", "cover_boot", "cover_boot_mcse",
  "width_boot", "cover_hybrid", "cover_hybrid_mcse", "width_hybrid",
  "bandset_boot", "bandset_boot_mcse", "bandset_boot_length",
  "compset_boot", "compset_boot_mcse", "compset_boot_length",
  "length_ratio_boot", "length_ratio_boot_mcse", "q_comp_boot",
  "bandset_hybrid", "bandset_hybrid_mcse", "bandset_hybrid_length",
  "compset_hybrid", "compset_hybrid_mcse", "compset_hybrid_length",
  "length_ratio_hybrid", "length_ratio_hybrid_mcse", "q_comp_hybrid",
  "q_rubin", "q_boot", "q_hybrid", "c_star_in_grid", "grid_lo", "grid_hi",
  "true_region_length", "gap", "gap_mcse", "gap_n_nonzero", "rmse_ratio",
  "rmse_ratio_mcse")

# The sharp-shape truth that SummarizeAllCellsC() computes.
sharp_truth <- MarkerTruth(2, 1)

# -- SummarizeCellC -------------------------------------------------------

test_that("SummarizeCellC returns one row with every measure", {
  out <- SummarizeCellC(FakeRepsC(), fake_truth_c)
  expect_s3_class(out, "data.frame")
  expect_equal(nrow(out), 1L)
  expect_named(out, summary_columns_c)
  expect_equal(out$n_rep, 4)
  expect_equal(out$miss_frac, 0.4)
})

test_that("SummarizeCellC's optimism and corrected biases are known means", {
  reps <- FakeRepsC()
  out <- SummarizeCellC(reps, fake_truth_c)
  # Hand values.
  expect_equal(out$optimism, 0.04)
  expect_equal(out$apparent_bias_star, 0.03)
  expect_equal(out$corrected_bias_20, -0.01)
  expect_equal(out$corrected_bias_2, 0.015)
  expect_equal(out$correction_20, 0.0475)
  expect_equal(out$correction_2, 0.025)
  expect_equal(out$bias_ratio_20, -0.25)
  expect_equal(out$bias_ratio_2, 0.375)
  # MCSEs are sd / sqrt(R) of the per-replicate values.
  opt <- reps$apparent - reps$j_at_c_hat
  err_20 <- reps$corrected_20 - reps$j_at_c_hat
  err_2 <- reps$corrected_2 - reps$j_at_c_hat
  expect_equal(out$optimism_mcse, sd(opt) / 2)
  expect_equal(out$apparent_bias_star_mcse, sd(reps$apparent) / 2)
  expect_equal(out$corrected_bias_20_mcse, sd(err_20) / 2)
  expect_equal(out$corrected_bias_2_mcse, sd(err_2) / 2)
  expect_gt(out$optimism_mcse, 0)
  # Delta-method MCSE of the ratio of means, from the residual form.
  r20 <- mean(err_20) / mean(opt)
  r2 <- mean(err_2) / mean(opt)
  expect_equal(out$bias_ratio_20_mcse,
               sd(err_20 - r20 * opt) / (2 * abs(mean(opt))))
  expect_equal(out$bias_ratio_2_mcse,
               sd(err_2 - r2 * opt) / (2 * abs(mean(opt))))
})

test_that("SummarizeCellC's coverage and width summaries are means", {
  out <- SummarizeCellC(FakeRepsC(), fake_truth_c)
  expect_equal(out$cover_pointwise, 0.25)
  expect_equal(out$cover_rubin, 0.75)
  expect_equal(out$cover_boot, 1)
  expect_equal(out$cover_hybrid, 0.75)
  # Binomial MCSE sqrt(p (1 - p) / R); zero when every replicate covers.
  expect_equal(out$cover_pointwise_mcse, sqrt(0.25 * 0.75 / 4))
  expect_equal(out$cover_rubin_mcse, sqrt(0.75 * 0.25 / 4))
  expect_equal(out$cover_boot_mcse, 0)
  expect_equal(out$cover_hybrid_mcse, sqrt(0.75 * 0.25 / 4))
  expect_equal(out$width_pointwise, 0.065)
  expect_equal(out$width_rubin, 0.105)
  expect_equal(out$width_boot, 0.13)
  expect_equal(out$width_hybrid, 0.14)
  expect_equal(out$q_rubin, 2.65)
  expect_equal(out$q_boot, 3.05)
  expect_equal(out$q_hybrid, 2.85)
})

test_that("SummarizeCellC's sets, lengths, and length ratios are as defined", {
  reps <- FakeRepsC()
  out <- SummarizeCellC(reps, fake_truth_c)
  expect_equal(out$bandset_boot, 0.75)
  expect_equal(out$compset_boot, 0.5)
  expect_equal(out$bandset_hybrid, 1)
  expect_equal(out$compset_hybrid, 0.75)
  expect_equal(out$bandset_boot_mcse, sqrt(0.75 * 0.25 / 4))
  expect_equal(out$compset_boot_mcse, sqrt(0.5 * 0.5 / 4))
  expect_equal(out$bandset_hybrid_mcse, 0)
  expect_equal(out$compset_hybrid_mcse, sqrt(0.75 * 0.25 / 4))
  expect_equal(out$bandset_boot_length, 0.45)
  expect_equal(out$compset_boot_length, 0.2)
  expect_equal(out$bandset_hybrid_length, 0.3)
  expect_equal(out$compset_hybrid_length, 0.15)
  expect_equal(out$q_comp_boot, 2.15)
  expect_equal(out$q_comp_hybrid, 2.05)
  # The ratio of the comparison-based to the band-based mean length, with
  # the delta-method MCSE in its residual form.
  expect_equal(out$length_ratio_boot, 0.2 / 0.45)
  expect_equal(out$length_ratio_hybrid, 0.5)
  for (con in c("boot", "hybrid")) {
    a <- reps[[paste0("compset_", con, "_length")]]
    b <- reps[[paste0("bandset_", con, "_length")]]
    r <- mean(a) / mean(b)
    expect_equal(out[[paste0("length_ratio_", con, "_mcse")]],
                 sd(a - r * b) / (2 * mean(b)))
  }
  # Constant band-based length: the MCSE is sd(a) / (sqrt(R) mean(b)).
  expect_equal(out$length_ratio_hybrid_mcse,
               sd(reps$compset_hybrid_length) / (2 * 0.3))
})

test_that("SummarizeCellC summarizes the gap and the cutoff's error", {
  out <- SummarizeCellC(FakeRepsC(), fake_truth_c)
  gap <- c(0, 0.01, 0.02, 0)
  expect_equal(out$gap, 0.0075)
  expect_equal(out$gap_mcse, sd(gap) / 2)
  expect_equal(out$gap_n_nonzero, 2)
  # c_hat errors against c* = 1: 0.1, -0.1, 0.2, 0; c_p2 errors: 0, 0, 0.1,
  # 0. The RMSE ratio is the square root of the ratio of mean squares.
  sq1 <- c(0.01, 0.01, 0.04, 0)
  sq2 <- c(0, 0, 0.01, 0)
  expect_equal(out$rmse_ratio, sqrt(mean(sq2) / mean(sq1)))
  expect_equal(out$rmse_ratio, sqrt(1 / 6))
  # The ratio of squared errors' MCSE (residual form), then the delta
  # method for the square root.
  r <- mean(sq2) / mean(sq1)
  mcse_r <- sd(sq2 - r * sq1) / (2 * mean(sq1))
  expect_equal(out$rmse_ratio_mcse, mcse_r / (2 * sqrt(r)))
})

test_that("SummarizeCellC reports the grid and whether it holds c*", {
  out <- SummarizeCellC(FakeRepsC(), fake_truth_c)
  expect_equal(out$grid_lo, mean(c(0.2, 0.2, 0.2, 1.5)))
  expect_equal(out$grid_hi, 2)
  # The replicate-level flag is averaged, not recomputed from c*.
  expect_equal(out$c_star_in_grid, 0.75)
})

test_that("SummarizeCellC's true region length comes from the shape", {
  out <- SummarizeCellC(FakeRepsC(), fake_truth_c)
  expect_equal(out$true_region_length, TrueNearRegionLength(2, 1))
  flat <- SummarizeCellC(FakeRepsC(), list(delta = 1.5, sigma1 = 2.5,
                                           c_star = 1, j_star = 0.7))
  expect_equal(flat$true_region_length, TrueNearRegionLength(1.5, 2.5))
})

test_that("SummarizeCellC uses the truth's J* and c* where the rule says", {
  low <- SummarizeCellC(FakeRepsC(), list(delta = 2, sigma1 = 1,
                                          c_star = 1.8, j_star = 0.6))
  expect_equal(low$apparent_bias_star, 0.13)
  expect_equal(low$rmse_ratio,
               sqrt(mean((c(1.0, 1.0, 1.1, 1.0) - 1.8)^2) /
                      mean((c(1.1, 0.9, 1.2, 1.0) - 1.8)^2)))
  # The biases against J(c_hat) do not involve J* or c*.
  expect_equal(low$optimism, 0.04)
  expect_equal(low$corrected_bias_20, -0.01)
})

test_that("SummarizeCellC ignores the labelling columns of RunDataCell", {
  reps <- FakeRepsC()
  labelled <- cbind(reps, rep = 1:4, cell = 2L, block = 1L)
  expect_equal(SummarizeCellC(labelled, fake_truth_c),
               SummarizeCellC(reps, fake_truth_c))
})

test_that("SummarizeCellC summarizes real replicates of a small cell", {
  cell <- PilotDesignC()
  cell <- cell[cell$cell == 2, ]
  cell$n <- 40L
  cell$n_imp <- 3L
  cell$seed <- 7L
  truth <- MarkerTruth(cell$delta, cell$sigma1)
  old <- RNGkind()
  on.exit(RNGkind(old[1], old[2], old[3]))
  reps <- RunDataCell(cell, 3, replicate_fun = function(cell, truth) {
    RunReplicateC(cell, truth, n_boot = 20L, m_boot = 2L, n_boot_opt = 5L,
                  n_boot_opt2 = 5L, grid_n = 9L, n_draw = 500L)
  })
  # The hand-made replicates have the same columns as the real ones.
  expect_equal(names(FakeRepsC()), setdiff(names(reps), c("rep", "cell")))
  out <- SummarizeCellC(reps, truth)
  expect_equal(nrow(out), 1L)
  expect_named(out, summary_columns_c)
  expect_equal(out$n_rep, 3)
  expect_true(all(is.finite(unlist(out[c("optimism", "optimism_mcse",
                                         "cover_boot", "compset_hybrid",
                                         "length_ratio_boot", "gap",
                                         "true_region_length")]))))
  expect_equal(out$optimism, mean(reps$apparent - reps$j_at_c_hat))
})

# -- SummarizeAllCellsC ---------------------------------------------------

# Replicates of one cell, shifted so each cell's summary is recognizable.
CellReps <- function(cell, shift = 0) {
  reps <- FakeRepsC()
  reps$apparent <- reps$apparent + shift
  reps$cell <- cell
  reps
}

test_that("SummarizeAllCellsC returns one row per cell, in cell order", {
  design <- PilotDesignC()
  reps <- rbind(CellReps(4L, 0.04), CellReps(1L), CellReps(3L, 0.02),
                CellReps(5L, 0.05), CellReps(2L, 0.01))
  out <- SummarizeAllCellsC(reps, design)
  expect_s3_class(out, "data.frame")
  expect_equal(nrow(out), 5L)
  expect_equal(out$cell, 1:5)
  expect_equal(rownames(out), as.character(1:5))
  # The design's columns, the cell's truth, then the summary.
  expect_equal(names(out), c(names(design), "c_star", "j_star",
                             summary_columns_c))
  expect_equal(out$engine, design$engine)
  expect_equal(out$miss_rate, design$miss_rate)
  expect_equal(out$c_star, rep(sharp_truth$c_star, 5))
  expect_equal(out$j_star, rep(sharp_truth$j_star, 5))
  # Each row summarizes its own cell's replicates.
  expect_equal(out$optimism, 0.04 + c(0, 0.01, 0.02, 0.04, 0.05))
  expect_equal(out$apparent_bias_star,
               mean(FakeRepsC()$apparent) - sharp_truth$j_star +
                 c(0, 0.01, 0.02, 0.04, 0.05))
})

test_that("SummarizeAllCellsC's row is the cell's SummarizeCellC", {
  design <- PilotDesignC()
  reps <- rbind(CellReps(2L, 0.01), CellReps(3L, 0.02))
  out <- SummarizeAllCellsC(reps, design)
  expect_equal(nrow(out), 2L)
  expect_equal(out$cell, 2:3)
  expected <- SummarizeCellC(CellReps(3L, 0.02), sharp_truth)
  expect_equal(out[out$cell == 3, summary_columns_c], expected,
               ignore_attr = TRUE)
})

test_that("SummarizeAllCellsC pools the blocks of a cell", {
  design <- PilotDesignC()
  block_1 <- CellReps(2L)
  block_1$block <- 1L
  block_2 <- CellReps(2L, 0.02)
  block_2$block <- 2L
  out <- SummarizeAllCellsC(rbind(block_1, block_2), design)
  expect_equal(nrow(out), 1L)
  expect_equal(out$n_rep, 8)
  expect_equal(out$optimism, 0.05)
})

# -- ApplyPassRuleC -------------------------------------------------------

# Summaries of cells 1 to 5 with the columns ApplyPassRuleC() reads, hand
# made so that every clause of the rule is met far from its threshold:
# optimism well beyond 3 MCSE and the 0.01 bar, the pointwise intervals
# failing to cover, the correction removing most of the optimism, both
# constructions' bands near 0.95 and their comparison-based sets holding
# the best threshold in 0.97 of replicates at 0.5 of the band-based length.
ClearPassSummaries <- function() {
  five <- function(x) rep(x, 5)
  data.frame(
    cell = 1:5,
    optimism = c(0, 0.03, 0.03, 0.05, 0.05),
    optimism_mcse = c(0.001, 0.002, 0.002, 0.003, 0.003),
    cover_pointwise = c(0.80, 0.50, 0.50, 0.40, 0.40),
    cover_pointwise_mcse = five(0.01),
    bias_ratio_20 = c(0, 0.1, -0.1, 0.1, 0.1),
    bias_ratio_20_mcse = five(0.02),
    cover_boot = five(0.95), cover_boot_mcse = five(0.003),
    cover_hybrid = five(0.95), cover_hybrid_mcse = five(0.003),
    compset_boot = five(0.97), compset_boot_mcse = five(0.003),
    compset_hybrid = five(0.97), compset_hybrid_mcse = five(0.003),
    length_ratio_boot = five(0.5), length_ratio_boot_mcse = five(0.02),
    length_ratio_hybrid = five(0.5), length_ratio_hybrid_mcse = five(0.02))
}

# Set one summary of one cell.
WithValue <- function(s, cell, column, value) {
  s[s$cell == cell, column] <- value
  s
}

test_that("a clear pass is 'piloted-pass' with nothing near", {
  out <- ApplyPassRuleC(ClearPassSummaries())
  expect_named(out, c("criteria", "questions", "constructions", "status"))
  expect_identical(out$status, "piloted-pass")
  expect_equal(out$questions$question, c("Q1", "Q2", "Q3"))
  expect_true(all(out$questions$passed))
  expect_false(any(out$questions$near))
  expect_equal(out$constructions$construction, c("boot", "hybrid"))
  expect_true(all(out$constructions$passed))
  expect_false(any(out$constructions$near))
})

test_that("ApplyPassRuleC lists 20 criteria, each with a verdict", {
  crit <- ApplyPassRuleC(ClearPassSummaries())$criteria
  expect_equal(nrow(crit), 20L)
  expect_true(all(c("question", "clause", "cell", "measure", "estimate",
                    "mcse", "rule", "met", "near") %in% names(crit)))
  expect_equal(table(crit$question)[["Q1"]], 2L)
  expect_equal(table(crit$question)[["Q2"]], 2L)
  expect_equal(table(crit$question)[["Q3"]], 16L)
  expect_equal(sum(crit$clause == "b, boot"), 7L)
  expect_equal(sum(crit$clause == "b, hybrid"), 7L)
  expect_true(all(crit$met))
  expect_false(any(crit$near))
})

test_that("Q1 failing gives 'piloted-fail', near its threshold or not", {
  # Optimism below 3 MCSE in the base cell.
  s <- WithValue(ClearPassSummaries(), 2, "optimism", 0.004)
  out <- ApplyPassRuleC(s)
  expect_identical(out$status, "piloted-fail")
  expect_false(out$questions$passed[1])
  # Just short of 3 MCSE (0.006): a near miss is still a failure of Q1.
  near <- ApplyPassRuleC(WithValue(ClearPassSummaries(), 2, "optimism",
                                   0.0055))
  expect_false(near$questions$passed[1])
  expect_true(near$questions$near[1])
  expect_identical(near$status, "piloted-fail")
  # The pointwise intervals covering at least 0.90.
  covered <- ApplyPassRuleC(WithValue(ClearPassSummaries(), 2,
                                      "cover_pointwise", 0.95))
  expect_false(covered$questions$passed[1])
  expect_identical(covered$status, "piloted-fail")
})

test_that("one construction failing far still passes Q3 through the other", {
  boot_fails <- WithValue(ClearPassSummaries(), 2, "cover_boot", 0.80)
  out <- ApplyPassRuleC(boot_fails)
  expect_identical(out$status, "piloted-pass")
  expect_equal(out$constructions$passed, c(FALSE, TRUE))
  expect_equal(out$constructions$near, c(FALSE, FALSE))
  expect_true(out$questions$passed[3])
  # And the same the other way round.
  hybrid_fails <- WithValue(ClearPassSummaries(), 3, "compset_hybrid", 0.60)
  out <- ApplyPassRuleC(hybrid_fails)
  expect_identical(out$status, "piloted-pass")
  expect_equal(out$constructions$passed, c(TRUE, FALSE))
})

test_that("both constructions failing far gives 'piloted-fail'", {
  s <- WithValue(ClearPassSummaries(), 2, "cover_boot", 0.80)
  s <- WithValue(s, 2, "cover_hybrid", 0.80)
  out <- ApplyPassRuleC(s)
  expect_identical(out$status, "piloted-fail")
  expect_true(out$questions$passed[1])
  expect_false(out$questions$passed[3])
  expect_false(out$questions$near[3])
  expect_equal(out$constructions$passed, c(FALSE, FALSE))
})

test_that("each judged clause of a construction can fail it", {
  # Failing far in the null cell, the base cell, or the normal twin; with
  # the other construction failing too, the status is 'piloted-fail'.
  fails <- list(
    list(1, "cover_boot", 0.99), list(2, "cover_boot", 0.88),
    list(3, "cover_boot", 0.99), list(2, "compset_boot", 0.80),
    list(3, "compset_boot", 0.80), list(2, "length_ratio_boot", 0.95),
    list(3, "length_ratio_boot", 0.95))
  for (f in fails) {
    s <- ClearPassSummaries()
    s <- WithValue(s, f[[1]], f[[2]], f[[3]])
    out <- ApplyPassRuleC(s)
    expect_equal(out$constructions$passed, c(FALSE, TRUE),
                 info = paste(f[[1]], f[[2]]))
    hybrid <- WithValue(s, f[[1]], sub("boot", "hybrid", f[[2]]), f[[3]])
    expect_identical(ApplyPassRuleC(hybrid)$status, "piloted-fail",
                     info = paste(f[[1]], f[[2]]))
  }
})

test_that("one construction near its threshold, the other far: close call", {
  # The bootstrap band covers 0.928 of replicates: short of 0.93 but within
  # 3 MCSE; the hybrid construction fails far.
  s <- WithValue(ClearPassSummaries(), 2, "cover_boot", 0.928)
  s <- WithValue(s, 2, "cover_boot_mcse", 0.005)
  s <- WithValue(s, 2, "cover_hybrid", 0.80)
  out <- ApplyPassRuleC(s)
  expect_identical(out$status, "piloted-close-call")
  expect_equal(out$constructions$passed, c(FALSE, FALSE))
  expect_equal(out$constructions$near, c(TRUE, FALSE))
  expect_false(out$questions$passed[3])
  expect_true(out$questions$near[3])
  # Both constructions short of the line but near it: also a close call.
  s_both <- WithValue(s, 2, "cover_hybrid", 0.926)
  s_both <- WithValue(s_both, 2, "cover_hybrid_mcse", 0.005)
  expect_identical(ApplyPassRuleC(s_both)$status, "piloted-close-call")
})

test_that("Q3(a) failing far gives 'piloted-fail' despite good bands", {
  out <- ApplyPassRuleC(WithValue(ClearPassSummaries(), 2, "bias_ratio_20",
                                  0.8))
  expect_identical(out$status, "piloted-fail")
  expect_true(all(out$constructions$passed))
  expect_false(out$questions$passed[3])
  expect_false(out$questions$near[3])
  # The sign of the corrected bias does not matter, and the normal twin
  # counts too.
  twin <- ApplyPassRuleC(WithValue(ClearPassSummaries(), 3, "bias_ratio_20",
                                   -0.8))
  expect_identical(twin$status, "piloted-fail")
})

test_that("Q3(a) failing but near, with good bands, is a close call", {
  s <- WithValue(ClearPassSummaries(), 2, "bias_ratio_20", 0.52)
  out <- ApplyPassRuleC(s)
  expect_identical(out$status, "piloted-close-call")
  expect_false(out$questions$passed[3])
  expect_true(out$questions$near[3])
  # Met but near the 0.5 line: also a close call.
  met <- ApplyPassRuleC(WithValue(ClearPassSummaries(), 2, "bias_ratio_20",
                                  -0.49))
  expect_true(met$questions$passed[3])
  expect_true(met$questions$near[3])
  expect_identical(met$status, "piloted-close-call")
})

test_that("a near clause matters only if every passing construction has one", {
  near_clause <- function(s, con) {
    s <- WithValue(s, 2, paste0("cover_", con), 0.931)
    WithValue(s, 2, paste0("cover_", con, "_mcse"), 0.005)
  }
  # Both pass; only the bootstrap has a near clause: the hybrid passing
  # clearly settles Q3.
  one <- ApplyPassRuleC(near_clause(ClearPassSummaries(), "boot"))
  expect_equal(one$constructions$passed, c(TRUE, TRUE))
  expect_equal(one$constructions$near, c(TRUE, FALSE))
  expect_false(one$questions$near[3])
  expect_identical(one$status, "piloted-pass")
  # Both pass and both have a near clause: a close call.
  both <- ApplyPassRuleC(near_clause(near_clause(ClearPassSummaries(),
                                                 "boot"), "hybrid"))
  expect_true(both$questions$near[3])
  expect_identical(both$status, "piloted-close-call")
  # Only the bootstrap passes, and its pass is near: a close call.
  only <- near_clause(WithValue(ClearPassSummaries(), 2, "cover_hybrid",
                                0.80), "boot")
  out <- ApplyPassRuleC(only)
  expect_equal(out$constructions$passed, c(TRUE, FALSE))
  expect_true(out$questions$near[3])
  expect_identical(out$status, "piloted-close-call")
})

test_that("Q2 is met by either the base cell or the 60% cell", {
  # Base cell short of 0.01 (but far enough from 3 MCSE for Q1), 60% cell
  # well above: Q2 still passes.
  s <- WithValue(ClearPassSummaries(), 2, "optimism", 0.008)
  s <- WithValue(s, 2, "optimism_mcse", 0.001)
  out <- ApplyPassRuleC(s)
  expect_true(out$questions$passed[2])
  expect_identical(out$status, "piloted-pass")
  # Neither reaches 0.01, far from it: Q2 fails, which is a close call
  # (only Q1 and Q3 failing far makes a failure).
  low <- WithValue(ClearPassSummaries(), 2, "optimism", 0.004)
  low <- WithValue(low, 2, "optimism_mcse", 0.0005)
  low <- WithValue(low, 4, "optimism", 0.004)
  low <- WithValue(low, 4, "optimism_mcse", 0.0005)
  out <- ApplyPassRuleC(low)
  expect_true(out$questions$passed[1])
  expect_false(out$questions$passed[2])
  expect_false(out$questions$near[2])
  expect_true(out$questions$passed[3])
  expect_identical(out$status, "piloted-close-call")
})

test_that("ApplyPassRuleC reads the right cells and no others", {
  base <- ApplyPassRuleC(ClearPassSummaries())
  # Cell 5 (60%, normal imputation) is not judged.
  s <- ClearPassSummaries()
  s[s$cell == 5, setdiff(names(s), "cell")] <- 0.123
  expect_equal(ApplyPassRuleC(s)$criteria, base$criteria)
  # The null cell's optimism and its sets are not judged either.
  s <- WithValue(ClearPassSummaries(), 1, "optimism", -1)
  s <- WithValue(s, 1, "compset_boot", 0)
  s <- WithValue(s, 1, "length_ratio_boot", 5)
  expect_equal(ApplyPassRuleC(s)$criteria, base$criteria)
  # Row order does not matter.
  shuffled <- ClearPassSummaries()[c(4, 1, 5, 3, 2), ]
  expect_equal(ApplyPassRuleC(shuffled)$criteria, base$criteria)
  # A missing or repeated cell is an error.
  expect_error(ApplyPassRuleC(ClearPassSummaries()[-3, ]))
  expect_error(ApplyPassRuleC(rbind(ClearPassSummaries(),
                                    ClearPassSummaries()[2, ])))
})

test_that("ApplyPassRuleC runs on the output of SummarizeAllCellsC", {
  design <- PilotDesignC()
  reps <- do.call(rbind, lapply(1:5, function(k) CellReps(k)))
  summaries <- SummarizeAllCellsC(reps, design)
  # Every column the rule reads is one the summaries carry.
  expect_true(all(setdiff(names(ClearPassSummaries()), "cell") %in%
                    names(summaries)))
  out <- ApplyPassRuleC(summaries)
  expect_true(out$status %in% c("piloted-pass", "piloted-fail",
                                "piloted-close-call"))
  expect_equal(nrow(out$criteria), 20L)
})
