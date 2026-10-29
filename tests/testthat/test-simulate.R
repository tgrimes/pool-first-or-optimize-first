# Tests for R/simulate.R: the pilot's design table, the analysis of one set
# of completed datasets, and the replicate and data-cell runners.

design <- PilotDesign()

# One design row, shrunk to a size that runs in a fraction of a second.
SmallCell <- function(cell_number, n = 30L, n_imp = 3L) {
  cell <- design[design$cell == cell_number, ]
  cell$n <- n
  cell$n_imp <- n_imp
  cell
}

# RunDataCell() switches the generator to L'Ecuyer-CMRG; put it back so the
# other tests see the generator they started with.
RunKeepingRng <- function(cell, n_rep) {
  old <- RNGkind()
  on.exit(RNGkind(old[1], old[2], old[3]))
  RunDataCell(cell, n_rep)
}

analysis_columns <- c(
  "estimator", "c_p1", "c_p2", "c_p3", "j_p1", "j_p2", "j_p3", "tj_p1",
  "tj_p2", "tj_p3", "gap", "b_c", "pred_gap", "pred_cdiff", "pred_gap_hat",
  "cover_mid", "cover_lo", "cover_hi", "width_mid")

test_that("PilotDesign has 22 data cells and the documented columns", {
  expect_s3_class(design, "data.frame")
  expect_equal(nrow(design), 22L)
  expect_named(design, c("cell", "shape", "delta", "sigma1", "miss_rate",
                         "alpha0", "n", "engine", "n_imp", "seed", "base"))
  expect_equal(design$cell, 1:22)
  expect_equal(sum(design$base), 1L)
  # The sharp shape carries the two extra-L cells (L = 5 and L = 100).
  expect_equal(sum(design$shape == "sharp"), 12L)
  expect_equal(sum(design$shape == "flat"), 10L)
  expect_equal(sum(design$engine == "none"), 4L)
  expect_equal(sum(design$engine == "nn"), 8L)
  expect_equal(sum(design$engine == "pmm"), 10L)
})

test_that("PilotDesign marks the base cell and the L = 5 and L = 100 cells", {
  base <- design[design$base, ]
  expect_equal(base$shape, "sharp")
  expect_equal(base$miss_rate, 0.4)
  expect_equal(base$n, 250)
  expect_equal(base$engine, "pmm")
  expect_equal(base$n_imp, 20)
  # SmallCell(3) in this file and cell 3 in test-summarize.R rely on this.
  expect_equal(base$cell, 3L)
  for (n_imp in c(5L, 100L)) {
    row <- design[design$n_imp == n_imp, ]
    expect_equal(nrow(row), 1L)
    expect_equal(row$shape, "sharp")
    expect_equal(row$miss_rate, 0.4)
    expect_equal(row$n, 250)
    expect_equal(row$engine, "pmm")
    expect_false(row$base)
  }
  expect_equal(sort(unique(design$n_imp)), c(5, 20, 100))
})

test_that("PilotDesign ties alpha0 and the engine to the missing fraction", {
  none <- design$miss_rate == 0
  expect_identical(is.na(design$alpha0), none)
  expect_identical(design$engine == "none", none)
  expect_equal(sum(none), 4L)
  expect_setequal(design$miss_rate, c(0, 0.4, 0.6))
  expect_setequal(design$n, c(250, 1000))
  # alpha0 solves for the cell's own shape and missing fraction.
  for (i in which(!none)) {
    expect_equal(design$alpha0[i],
                 MissingIntercept(design$miss_rate[i], design$delta[i],
                                  design$sigma1[i]))
  }
})

test_that("PilotDesign shapes and seeds follow the pre-registration", {
  sharp <- design[design$shape == "sharp", ]
  flat <- design[design$shape == "flat", ]
  expect_true(all(sharp$delta == 2 & sharp$sigma1 == 1))
  expect_true(all(flat$delta == 1.5 & flat$sigma1 == 2.5))
  expect_equal(design$seed, 20261028 + design$cell)
  expect_equal(PilotDesign(1000L)$seed, 1000 + design$cell)
  expect_equal(anyDuplicated(design$seed), 0L)
  expect_identical(PilotDesign(), design)
})

test_that("AnalyseCompleted (empirical) returns one well-formed row", {
  set.seed(1)
  cell <- SmallCell(3)
  truth <- MarkerTruth(cell$delta, cell$sigma1)
  dat <- SimulateMarkerData(cell$n, cell$delta, cell$sigma1, cell$alpha0)
  completed <- ImputePmm(dat$x, dat$d, dat$z, cell$n_imp)
  out <- AnalyseCompleted(completed, dat$d, dat$observed, "empirical", truth)
  expect_s3_class(out, "data.frame")
  expect_equal(nrow(out), 1L)
  expect_named(out, analysis_columns)
  expect_equal(out$estimator, "empirical")
  expect_equal(out$gap, out$j_p2 - out$j_p1)
  expect_gte(out$gap, -1e-12)
  expect_gte(out$b_c, 0)
  expect_true(all(unlist(out[c("cover_mid", "cover_lo", "cover_hi")]) %in%
                    c(0, 1)))
  expect_gt(out$width_mid, 0)
  # The true index at any cutoff cannot exceed the true maximum.
  expect_true(all(unlist(out[c("tj_p1", "tj_p2", "tj_p3")]) <=
                    truth$j_star + 1e-12))
  expect_equal(out$tj_p1, TrueYouden(out$c_p1, truth$delta, truth$sigma1))
  expect_equal(out$tj_p2, TrueYouden(out$c_p2, truth$delta, truth$sigma1))
  expect_equal(out$tj_p3, TrueYouden(out$c_p3, truth$delta, truth$sigma1))
  # Predictions of the gap and of the cutoff difference.
  expect_equal(out$pred_gap, truth$kappa * out$b_c / 2)
  expect_equal(out$pred_cdiff, truth$tau * out$b_c / (2 * truth$kappa))
  expect_true(is.na(out$pred_gap_hat))
})

test_that("AnalyseCompleted (kernel) returns a curvature-based prediction", {
  set.seed(2)
  cell <- SmallCell(3)
  truth <- MarkerTruth(cell$delta, cell$sigma1)
  dat <- SimulateMarkerData(cell$n, cell$delta, cell$sigma1, cell$alpha0)
  completed <- ImputePmm(dat$x, dat$d, dat$z, cell$n_imp)
  out <- AnalyseCompleted(completed, dat$d, dat$observed, "kernel", truth)
  expect_named(out, analysis_columns)
  expect_equal(out$estimator, "kernel")
  expect_gte(out$gap, -1e-10)
  expect_true(is.finite(out$pred_gap_hat))
  expect_true(all(unlist(out[c("cover_mid", "cover_lo", "cover_hi")]) %in%
                    c(0, 1)))
  expect_gt(out$width_mid, 0)
})

test_that("AnalyseCompleted of identical datasets has gap exactly 0", {
  set.seed(3)
  truth <- MarkerTruth(2, 1)
  dat <- SimulateMarkerData(30, 2, 1)
  completed <- matrix(dat$x_full, nrow = 60, ncol = 4)
  for (est in c("empirical", "kernel")) {
    out <- AnalyseCompleted(completed, dat$d, dat$observed, est, truth)
    expect_identical(out$gap, 0)
    expect_identical(out$c_p1, out$c_p2)
    expect_identical(out$c_p1, out$c_p3)
    expect_identical(out$j_p1, out$j_p2)
    expect_equal(out$b_c, 0)
    expect_equal(out$pred_gap, 0)
  }
})

test_that("AnalyseCompleted's complete-data interval is the plain Wald one", {
  set.seed(4)
  truth <- MarkerTruth(2, 1)
  n <- 40
  dat <- SimulateMarkerData(n, 2, 1)
  completed <- matrix(dat$x_full, nrow = 2 * n, ncol = 3)
  x0 <- dat$x_full[dat$d == 0]
  x1 <- dat$x_full[dat$d == 1]
  # Empirical: with no between-imputation variance, J-hat(c*) +- 1.96 SE.
  out <- AnalyseCompleted(completed, dat$d, dat$observed, "empirical", truth)
  f0 <- mean(x0 <= truth$c_star)
  f1 <- mean(x1 <= truth$c_star)
  se <- sqrt(f0 * (1 - f0) / n + f1 * (1 - f1) / n)
  expect_equal(out$width_mid, 2 * qnorm(0.975) * se, tolerance = 1e-10)
  j_true <- TrueYouden(truth$c_star, 2, 1)
  covered <- abs((f0 - f1) - j_true) <= qnorm(0.975) * se
  expect_equal(out$cover_mid, as.numeric(covered))
  # Kernel: the same with the smoothed distribution functions.
  kc <- KernelCurves(completed, dat$d)
  g0 <- KernelCdf(truth$c_star, x0, kc$h0[[1]])
  g1 <- KernelCdf(truth$c_star, x1, kc$h1[[1]])
  se_k <- sqrt(g0 * (1 - g0) / n + g1 * (1 - g1) / n)
  outk <- AnalyseCompleted(completed, dat$d, dat$observed, "kernel", truth)
  expect_equal(outk$width_mid, 2 * qnorm(0.975) * se_k, tolerance = 1e-10)
  covered_k <- abs((g0 - g1) - j_true) <= qnorm(0.975) * se_k
  expect_equal(outk$cover_mid, as.numeric(covered_k))
})

test_that("AnalyseCompleted's empirical optimum is the full-data optimum", {
  set.seed(5)
  truth <- MarkerTruth(2, 1)
  dat <- SimulateMarkerData(35, 2, 1)
  completed <- matrix(dat$x_full, nrow = 70, ncol = 2)
  out <- AnalyseCompleted(completed, dat$d, dat$observed, "empirical", truth)
  curves <- EmpiricalCurves(matrix(dat$x_full), dat$d)
  single <- MaximizeStep(curves$u, curves$values[1, ])
  expect_equal(out$c_p1, single$cutoff)
  expect_equal(out$j_p1, single$value)
})

test_that("RunReplicate with engine 'none' has gap exactly 0, no missing", {
  set.seed(6)
  cell <- SmallCell(1)
  expect_equal(cell$engine, "none")
  truth <- MarkerTruth(cell$delta, cell$sigma1)
  out <- RunReplicate(cell, truth)
  expect_equal(nrow(out), 2L)
  expect_equal(out$estimator, c("empirical", "kernel"))
  expect_named(out, c(analysis_columns, "miss_frac"))
  expect_identical(out$gap, c(0, 0))
  expect_equal(out$miss_frac, c(0, 0))
  expect_equal(out$b_c, c(0, 0))
})

test_that("RunReplicate runs the PMM engine and records missingness", {
  set.seed(7)
  cell <- SmallCell(3)
  truth <- MarkerTruth(cell$delta, cell$sigma1)
  out <- RunReplicate(cell, truth)
  expect_equal(nrow(out), 2L)
  expect_named(out, c(analysis_columns, "miss_frac"))
  expect_true(all(out$gap >= -1e-10))
  expect_true(all(out$miss_frac > 0 & out$miss_frac < 1))
  expect_equal(out$miss_frac[1], out$miss_frac[2])
  expect_true(all(unlist(out[c("cover_mid", "cover_lo", "cover_hi")]) %in%
                    c(0, 1)))
})

test_that("RunReplicate runs the nearest-neighbour engine", {
  set.seed(8)
  cell <- SmallCell(7)
  expect_equal(cell$engine, "nn")
  truth <- MarkerTruth(cell$delta, cell$sigma1)
  out <- RunReplicate(cell, truth)
  expect_equal(nrow(out), 2L)
  expect_true(all(out$gap >= -1e-10))
  expect_true(all(out$miss_frac > 0))
})

test_that("RunReplicate applies only the requested estimators", {
  set.seed(9)
  cell <- SmallCell(3)
  truth <- MarkerTruth(cell$delta, cell$sigma1)
  out <- RunReplicate(cell, truth, estimators = "kernel")
  expect_equal(out$estimator, "kernel")
  expect_equal(nrow(out), 1L)
})

test_that("RunDataCell returns n_rep x 2 rows, labelled", {
  cell <- SmallCell(3)
  out <- RunKeepingRng(cell, 4)
  expect_equal(nrow(out), 8L)
  expect_true(all(c("rep", "cell") %in% names(out)))
  expect_equal(out$rep, rep(1:4, each = 2))
  expect_equal(out$cell, rep(3L, 8))
  expect_equal(out$estimator, rep(c("empirical", "kernel"), times = 4))
  expect_gte(attr(out, "seconds"), 0)
  expect_true(all(out$gap >= -1e-10))
})

test_that("RunDataCell is reproducible, whatever the generator state", {
  cell <- SmallCell(3)
  set.seed(1)
  a <- RunKeepingRng(cell, 3)
  set.seed(999)
  runif(10)
  b <- RunKeepingRng(cell, 3)
  attr(a, "seconds") <- NULL
  attr(b, "seconds") <- NULL
  expect_identical(a, b)
  # A different seed gives different data.
  other <- cell
  other$seed <- cell$seed + 1L
  d <- RunKeepingRng(other, 3)
  attr(d, "seconds") <- NULL
  expect_false(identical(a$c_p1, d$c_p1))
})

test_that("RunDataCell of a no-missing cell has gap 0 in every replicate", {
  cell <- SmallCell(1)
  out <- RunKeepingRng(cell, 3)
  expect_equal(nrow(out), 6L)
  expect_identical(out$gap, rep(0, 6))
})
