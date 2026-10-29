# Code paths the study's design adds to pilot-c's (protocol.md): unequal
# groups, the ten-donor and complete-case engines, the plug-in critical
# value, the bagged cutoff, the diagnostics, and the study's summaries.

StudyCell <- function(engine, miss_rate = 0.4, n = 40L, n1 = n,
                      delta = 2, sigma1 = 1, n_imp = 3L) {
  data.frame(cell = 1L, shape = "s", delta = delta, sigma1 = sigma1,
             miss_rate = miss_rate,
             alpha0 = if (miss_rate > 0) {
               MissingIntercept(miss_rate, delta, sigma1,
                                p1 = n1 / (n + n1))
             } else NA_real_,
             n = as.integer(n), engine = engine, n_imp = as.integer(n_imp),
             base = FALSE, n1 = as.integer(n1))
}
SmallStudyReplicate <- function(cell) {
  RunReplicateC(cell, MarkerTruth(cell$delta, cell$sigma1), n_boot = 20L,
                m_boot = 2L, n_boot_opt = 5L, n_boot_opt2 = 5L, grid_n = 9L,
                n_draw = 500L)
}

test_that("the separated shape has its closed-form optimum", {
  # Equal variances: c* = delta / 2 and J* = 2 Phi(delta / 2) - 1.
  t3 <- MarkerTruth(3, 1)
  expect_equal(t3$c_star, 1.5, tolerance = 1e-8)
  expect_equal(t3$j_star, 2 * stats::pnorm(1.5) - 1, tolerance = 1e-10)
  expect_equal(t3$kappa, 3 * stats::dnorm(1.5), tolerance = 1e-8)
})

test_that("SimulateMarkerData draws the requested group sizes", {
  set.seed(1)
  dat <- SimulateMarkerData(30, 2, 1, n1 = 10)
  expect_equal(sum(dat$d == 0), 30)
  expect_equal(sum(dat$d == 1), 10)
})

test_that("MissingIntercept hits the target fraction with unequal groups", {
  a0 <- MissingIntercept(0.4, 2, 1, p1 = 0.2)
  set.seed(2)
  dat <- SimulateMarkerData(80000, 2, 1, alpha0 = a0, n1 = 20000)
  expect_equal(mean(!dat$observed), 0.4, tolerance = 0.01)
  expect_equal(MissingIntercept(0.4, 2, 1, p1 = 0.5),
               MissingIntercept(0.4, 2, 1))
})

test_that("SimulationDesign handles unequal groups and arms without nulls", {
  sharp <- data.frame(shape = "sharp", delta = 2, sigma1 = 1)
  u <- SimulationDesign(sharp, n = 400L, miss_rates = 0.4,
                        engines = c("pmm", "norm"), n_cases = 100L)
  expect_equal(u$n1, rep(100L, 3))
  expect_equal(u$alpha0[2], MissingIntercept(0.4, 2, 1, p1 = 0.2))
  expect_false(any(u$base))
  c10 <- SimulationDesign(sharp, n = 250L, miss_rates = c(0.2, 0.4),
                          engines = "pmm10", include_null = FALSE)
  expect_equal(c10$engine, c("pmm10", "pmm10"))
  expect_false(any(c10$miss_rate == 0))
  all <- CombineDesigns(list(u, c10))
  expect_equal(all$cell, 1:5)
})

test_that("CellLabel names the new engines and unequal groups", {
  sharp <- data.frame(shape = "sharp", delta = 2, sigma1 = 1)
  d <- CombineDesigns(list(
    SimulationDesign(sharp, 250L, 0.4, c("pmm10", "cc"),
                     include_null = FALSE),
    SimulationDesign(sharp, 400L, 0.4, "pmm", n_cases = 100L,
                     include_null = FALSE)))
  expect_equal(CellLabel(d), c("n = 250, 40% PMM, 10 donors",
                               "n = 250, 40% complete cases",
                               "100 cases, 400 controls, 40% PMM"))
})

test_that("ImputeWith matches on ten donors and keeps observed values", {
  set.seed(3)
  dat <- SimulateMarkerData(50, 2, 1, alpha0 = MissingIntercept(0.4, 2, 1))
  comp <- ImputeWith("pmm10", dat$x, dat$d, dat$z, 4)
  expect_equal(dim(comp), c(100, 4))
  expect_equal(comp[dat$observed, 1], dat$x[dat$observed])
  expect_true(all(comp[!dat$observed, ] %in% dat$x[dat$observed]))
})

test_that("ComparisonQuantiles' largest value is the critical value", {
  set.seed(4)
  draws <- matrix(stats::rnorm(4000 * 3), ncol = 3)
  q <- ComparisonQuantiles(draws, diag(3))
  expect_length(q, 3)
  expect_equal(max(q), ComparisonCritical(draws, diag(3)))
  z2 <- matrix(stats::rnorm(100000 * 2), ncol = 2)
  expect_equal(ComparisonQuantiles(z2, diag(2)),
               rep(stats::qnorm(0.95), 2), tolerance = 0.02)
})

test_that("MiYoudenInference on complete data has no pooling-order gap", {
  set.seed(5)
  dat <- SimulateMarkerData(40, 2, 1)
  Copies <- function(rows, m) matrix(dat$x_full[rows], length(rows), m)
  res <- MiYoudenInference(dat$d, Copies, n_imp = 3L, n_boot = 20L,
                           n_boot_opt = 5L, n_boot_opt2 = 5L, grid_n = 9L,
                           n_draw = 500L)
  expect_identical(res$gap, 0)
  expect_identical(res$b_c, 0)
  expect_identical(res$c_p2, res$c_hat)
  for (con in c("boot", "hybrid")) {
    r <- res[[con]]
    expect_lte(r$q_comp_plugin, r$q_comp)
    # A smaller critical value can only drop thresholds from the set.
    expect_true(all(r$comp_set_plugin <= r$comp_set))
  }
  expect_true(res$c_bag >= min(dat$x_full) && res$c_bag <= max(dat$x_full))
})

test_that("RunReplicateC analyses the complete cases without imputing", {
  set.seed(6)
  out <- SmallStudyReplicate(StudyCell("cc", n = 60L))
  expect_gt(out$miss_frac, 0)
  expect_equal(out$n_used, round((1 - out$miss_frac) * 120))
  expect_identical(out$gap, 0)
})

test_that("RunReplicateC runs with ten donors and with unequal groups", {
  set.seed(7)
  out <- SmallStudyReplicate(StudyCell("pmm10"))
  expect_equal(out$n_used, 80)
  set.seed(8)
  un <- SmallStudyReplicate(StudyCell("norm", n = 60L, n1 = 20L))
  expect_equal(un$n_used, 80)
  expect_true(is.finite(un$c_bag))
})

test_that("SummarizeStudyCell extends pilot-c's summary", {
  cell <- StudyCell("pmm")
  truth <- MarkerTruth(2, 1)
  kind <- RNGkind()
  on.exit(RNGkind(kind[1], kind[2], kind[3]))
  set.seed(9)
  reps <- do.call(rbind, lapply(1:6, function(r) SmallStudyReplicate(cell)))
  s <- SummarizeStudyCell(reps, truth)
  old <- SummarizeCellC(reps, truth)
  expect_equal(s[, names(old)], old)
  expect_equal(s$cutoff_rmse, sqrt(mean((reps$c_hat - 1)^2)))
  expect_equal(s$regret, mean(truth$j_star - reps$j_at_c_hat))
  expect_equal(s$pred_gap, mean(truth$kappa * reps$b_c / 2))
  expect_equal(s$curve_bias_best, mean(reps$est_best - reps$j_best))
  expect_true(all(c("compplug_boot", "compplug_hybrid_length",
                    "rmse_ratio_bag", "sd_se_ratio") %in% names(s)))
})

test_that("SummarizeStudy labels every cell", {
  design <- CombineDesigns(list(StudyCell("pmm"), StudyCell("norm")))
  design$shape <- "sharp"
  kind <- RNGkind()
  on.exit(RNGkind(kind[1], kind[2], kind[3]))
  set.seed(10)
  reps <- do.call(rbind, lapply(1:2, function(k) {
    r <- do.call(rbind, lapply(1:3, function(i) {
      SmallStudyReplicate(design[k, ])
    }))
    r$cell <- k
    r
  }))
  s <- SummarizeStudy(reps, design)
  expect_equal(nrow(s), 2)
  expect_equal(s$label, c("40% PMM", "40% normal"))
})
