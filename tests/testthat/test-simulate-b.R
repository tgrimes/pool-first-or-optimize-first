# Tests for R/simulate_b.R: the re-pilot's design table and its replicate
# (pilot-b/preregistration.md, sections 2 and 3).

design_b <- PilotDesignB()

# One design row, shrunk to a size that runs in a fraction of a second.
SmallCellB <- function(cell_number, n = 40L, n_imp = 3L) {
  cell <- design_b[design_b$cell == cell_number, ]
  cell$n <- n
  cell$n_imp <- n_imp
  cell
}

# One small replicate.
SmallReplicate <- function(cell, truth = NULL) {
  if (is.null(truth)) truth <- MarkerTruth(cell$delta, cell$sigma1)
  RunReplicateB(cell, truth, n_boot = 10L, m_boot = 2L, grid_n = 9L,
                n_draw = 500L)
}

# RunDataCell() switches the generator to L'Ecuyer-CMRG; put it back so the
# other tests see the generator they started with.
RunSmallCell <- function(cell, n_rep) {
  old <- RNGkind()
  on.exit(RNGkind(old[1], old[2], old[3]))
  RunDataCell(cell, n_rep, replicate_fun = function(cell, truth) {
    SmallReplicate(cell, truth)
  })
}

replicate_columns <- c(
  "c_hat", "apparent", "apparent_at_c_hat", "j_at_c_hat", "corrected",
  "mean_optimism", "c_p2", "gap", "b_c", "pred_gap", "cover_pointwise",
  "cover_rubin", "cover_boot", "width_pointwise", "width_rubin",
  "width_boot", "q_rubin", "q_boot", "set_rubin_contains",
  "set_rubin_length", "set_boot_contains", "set_boot_length", "cover_star",
  "grid_lo", "grid_hi", "k_mid", "miss_frac")

# -- PilotDesignB -------------------------------------------------------

test_that("PilotDesignB has 10 cells and the documented columns", {
  expect_s3_class(design_b, "data.frame")
  expect_equal(nrow(design_b), 10L)
  expect_named(design_b, c("cell", "shape", "delta", "sigma1", "miss_rate",
                           "alpha0", "n", "engine", "n_imp", "seed",
                           "base"))
  expect_equal(design_b$cell, 1:10)
  expect_true(all(design_b$n == 250L))
  expect_true(all(design_b$n_imp == 20L))
})

test_that("PilotDesignB has one base cell: sharp, 40% missing, PMM", {
  expect_equal(sum(design_b$base), 1L)
  base <- design_b[design_b$base, ]
  expect_equal(base$shape, "sharp")
  expect_equal(base$miss_rate, 0.4)
  expect_equal(base$engine, "pmm")
  # The cells the pass rule picks are each unique.
  sharp <- design_b[design_b$shape == "sharp", ]
  for (pick in list(c(0.4, "pmm"), c(0.4, "norm"), c(0.6, "pmm"))) {
    expect_equal(sum(sharp$miss_rate == as.numeric(pick[1]) &
                       sharp$engine == pick[2]), 1L)
  }
})

test_that("PilotDesignB crosses shape, missing fraction, and engine", {
  for (shape in c("sharp", "flat")) {
    rows <- design_b[design_b$shape == shape, ]
    expect_equal(nrow(rows), 5L)
    expect_equal(rows$miss_rate, c(0, 0.4, 0.4, 0.6, 0.6))
    expect_equal(rows$engine, c("none", "pmm", "norm", "pmm", "norm"))
  }
  sharp <- design_b[design_b$shape == "sharp", ]
  flat <- design_b[design_b$shape == "flat", ]
  expect_true(all(sharp$delta == 2 & sharp$sigma1 == 1))
  expect_true(all(flat$delta == 1.5 & flat$sigma1 == 2.5))
})

test_that("PilotDesignB seeds cell k with 20261029 + k", {
  expect_equal(design_b$seed, 20261029L + design_b$cell)
  shifted <- PilotDesignB(base_seed = 100L)
  expect_equal(shifted$seed, 100L + shifted$cell)
  # Only the seeds change.
  expect_equal(shifted[, names(shifted) != "seed"],
               design_b[, names(design_b) != "seed"])
})

test_that("PilotDesignB has no engine or intercept iff nothing is missing", {
  expect_equal(design_b$engine == "none", design_b$miss_rate == 0)
  expect_equal(is.na(design_b$alpha0), design_b$miss_rate == 0)
  imputed <- design_b[design_b$miss_rate > 0, ]
  expected <- mapply(MissingIntercept, imputed$miss_rate, imputed$delta,
                     imputed$sigma1)
  expect_equal(imputed$alpha0, unname(expected))
})

# -- RunReplicateB ------------------------------------------------------

test_that("RunReplicateB returns one row with the documented columns", {
  set.seed(101)
  out <- SmallReplicate(SmallCellB(2))
  expect_s3_class(out, "data.frame")
  expect_equal(nrow(out), 1L)
  expect_named(out, replicate_columns)
})

test_that("RunReplicateB's coverage columns are logical, the rest numeric", {
  set.seed(102)
  out <- SmallReplicate(SmallCellB(2))
  logical_cols <- c("cover_pointwise", "cover_rubin", "cover_boot",
                    "set_rubin_contains", "set_boot_contains", "cover_star")
  for (nm in logical_cols) {
    expect_type(out[[nm]], "logical")
    expect_false(is.na(out[[nm]]))
  }
  numeric_cols <- setdiff(replicate_columns, logical_cols)
  for (nm in numeric_cols) {
    expect_true(is.numeric(out[[nm]]), info = nm)
    expect_true(is.finite(out[[nm]]), info = nm)
  }
})

test_that("RunReplicateB's index, gap, and bands obey their identities", {
  cell <- SmallCellB(2)
  truth <- MarkerTruth(cell$delta, cell$sigma1)
  for (seed in 103:106) {
    set.seed(seed)
    out <- SmallReplicate(cell, truth)
    # The maximum is at least the value at the chosen cutoff, and the mean
    # of the per-dataset maxima is at least the maximum of the mean.
    expect_gte(out$apparent, out$apparent_at_c_hat - 1e-12)
    expect_gte(out$gap, -1e-12)
    # corrected = value at the cutoff minus the mean bootstrap optimism.
    expect_equal(out$corrected, out$apparent_at_c_hat - out$mean_optimism)
    # The true curve at the chosen cutoff cannot beat the true maximum.
    expect_lte(out$j_at_c_hat, truth$j_star + 1e-12)
    expect_equal(out$j_at_c_hat,
                 TrueYouden(out$c_hat, truth$delta, truth$sigma1))
    expect_equal(out$pred_gap, truth$kappa * out$b_c / 2)
    expect_gte(out$b_c, 0)
    # Grid and widths.
    expect_lt(out$grid_lo, out$grid_hi)
    expect_true(out$k_mid >= 1 && out$k_mid <= 9)
    expect_true(all(c(out$width_pointwise, out$width_rubin,
                      out$width_boot) > 0))
    expect_gt(out$q_rubin, 1.5)
    expect_gt(out$q_boot, 1)
    expect_gte(out$set_rubin_length, 0)
    expect_gte(out$set_boot_length, 0)
    expect_true(out$miss_frac >= 0 && out$miss_frac <= 1)
  }
})

test_that("RunReplicateB sees missing values iff the cell has them", {
  set.seed(107)
  imputed <- SmallReplicate(SmallCellB(2))
  expect_gt(imputed$miss_frac, 0)
  set.seed(107)
  null <- SmallReplicate(SmallCellB(1))
  expect_equal(null$miss_frac, 0)
})

test_that("RunReplicateB with no imputation has a gap of exactly zero", {
  cell <- SmallCellB(1)
  expect_equal(cell$engine, "none")
  for (seed in 108:110) {
    set.seed(seed)
    out <- SmallReplicate(cell)
    expect_identical(out$gap, 0)
    expect_identical(out$b_c, 0)
    expect_identical(out$pred_gap, 0)
    # All datasets are the same, so the per-dataset cutoff is the pooled one.
    expect_identical(out$c_p2, out$c_hat)
  }
})

test_that("RunReplicateB runs with normal imputation too", {
  set.seed(111)
  out <- SmallReplicate(SmallCellB(3))
  expect_equal(nrow(out), 1L)
  expect_named(out, replicate_columns)
  expect_gte(out$gap, -1e-12)
})

test_that("RunReplicateB is reproducible given the seed", {
  cell <- SmallCellB(2)
  set.seed(112)
  a <- SmallReplicate(cell)
  set.seed(112)
  b <- SmallReplicate(cell)
  expect_identical(a, b)
  set.seed(113)
  expect_false(identical(a$c_hat, SmallReplicate(cell)$c_hat))
})

# -- RunDataCell with RunReplicateB -------------------------------------

test_that("RunDataCell collects RunReplicateB rows, labelled", {
  cell <- SmallCellB(2)
  out <- RunSmallCell(cell, 2)
  expect_equal(nrow(out), 2L)
  expect_true(all(c("rep", "cell") %in% names(out)))
  expect_equal(out$rep, 1:2)
  expect_equal(out$cell, rep(2L, 2))
  expect_true(all(replicate_columns %in% names(out)))
  expect_gte(attr(out, "seconds"), 0)
})

test_that("RunDataCell with RunReplicateB is reproducible", {
  cell <- SmallCellB(2)
  set.seed(1)
  a <- RunSmallCell(cell, 2)
  set.seed(999)
  runif(10)
  b <- RunSmallCell(cell, 2)
  attr(a, "seconds") <- NULL
  attr(b, "seconds") <- NULL
  expect_identical(a, b)
  other <- cell
  other$seed <- cell$seed + 1L
  d <- RunSmallCell(other, 2)
  attr(d, "seconds") <- NULL
  expect_false(identical(a$c_hat, d$c_hat))
})

test_that("RunDataCell of a no-missing cell has gap 0 in every replicate", {
  out <- RunSmallCell(SmallCellB(1), 3)
  expect_equal(nrow(out), 3L)
  expect_identical(out$gap, rep(0, 3))
})
