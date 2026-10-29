# Tests for R/simulate_c.R: pilot-c's design table, its blocks and seeds,
# and its replicate (pilot-c/preregistration.md, sections 2 and 3).

design_c <- PilotDesignC()

# One design row, shrunk to a size that runs in a fraction of a second.
SmallCellC <- function(cell_number, n = 40L, n_imp = 3L) {
  cell <- design_c[design_c$cell == cell_number, ]
  cell$n <- n
  cell$n_imp <- n_imp
  cell
}

# One small replicate.
SmallReplicateC <- function(cell, truth = NULL) {
  if (is.null(truth)) truth <- MarkerTruth(cell$delta, cell$sigma1)
  RunReplicateC(cell, truth, n_boot = 20L, m_boot = 2L, n_boot_opt = 5L,
                n_boot_opt2 = 5L, grid_n = 9L, n_draw = 500L)
}

# RunDataCell() switches the generator to L'Ecuyer-CMRG; put it back so the
# other tests see the generator they started with.
RunSmallCellC <- function(block, n_rep) {
  old <- RNGkind()
  on.exit(RNGkind(old[1], old[2], old[3]))
  RunDataCell(block, n_rep, replicate_fun = function(cell, truth) {
    SmallReplicateC(cell, truth)
  })
}

# A one-block row of BlockTable() for a cell, shrunk the same way.
SmallBlockC <- function(cell_number, n_rep = 2L) {
  blocks <- BlockTable(design_c, n_rep, block_size = n_rep)
  block <- blocks[blocks$cell == cell_number, ]
  block$n <- 40L
  block$n_imp <- 3L
  block
}

# The columns RunReplicateC() returns, in order.
replicate_columns_c <- c(
  "c_hat", "apparent", "apparent_at_c_hat", "j_at_c_hat", "corrected_20",
  "optimism_20", "corrected_2", "optimism_2", "c_p2", "gap",
  "cover_pointwise", "cover_rubin", "width_pointwise", "width_rubin",
  "q_rubin", "q_boot", "q_hybrid", "cover_boot", "width_boot",
  "bandset_boot_contains", "bandset_boot_length", "compset_boot_contains",
  "compset_boot_length", "q_comp_boot", "cover_hybrid", "width_hybrid",
  "bandset_hybrid_contains", "bandset_hybrid_length",
  "compset_hybrid_contains", "compset_hybrid_length", "q_comp_hybrid",
  "c_star_in_grid", "grid_lo", "grid_hi", "miss_frac",
  # added for the study's design (protocol.md)
  "compplug_boot_contains", "compplug_boot_length", "q_plug_boot",
  "compplug_hybrid_contains", "compplug_hybrid_length", "q_plug_hybrid",
  "b_c", "c_bag", "est_best", "j_best", "se_best", "se_rubin_best",
  "n_used")

logical_columns_c <- c(
  "cover_pointwise", "cover_rubin", "cover_boot", "cover_hybrid",
  "bandset_boot_contains", "compset_boot_contains",
  "bandset_hybrid_contains", "compset_hybrid_contains", "c_star_in_grid",
  "compplug_boot_contains", "compplug_hybrid_contains")

# -- PilotDesignC ---------------------------------------------------------

test_that("PilotDesignC has 5 cells and the documented columns", {
  expect_s3_class(design_c, "data.frame")
  expect_equal(nrow(design_c), 5L)
  expect_named(design_c, c("cell", "shape", "delta", "sigma1", "miss_rate",
                           "alpha0", "n", "engine", "n_imp", "base"))
  expect_equal(design_c$cell, 1:5)
})

test_that("PilotDesignC is the sharp shape at 250 per group, L = 20", {
  expect_true(all(design_c$shape == "sharp"))
  expect_true(all(design_c$delta == 2 & design_c$sigma1 == 1))
  expect_true(all(design_c$n == 250L))
  expect_true(all(design_c$n_imp == 20L))
  expect_equal(design_c$miss_rate, c(0, 0.4, 0.4, 0.6, 0.6))
  expect_equal(design_c$engine, c("none", "pmm", "norm", "pmm", "norm"))
})

test_that("PilotDesignC's base cell is cell 2 (40%, PMM) and only that", {
  expect_equal(design_c$base, c(FALSE, TRUE, FALSE, FALSE, FALSE))
  base <- design_c[design_c$base, ]
  expect_equal(base$cell, 2L)
  expect_equal(base$miss_rate, 0.4)
  expect_equal(base$engine, "pmm")
})

test_that("PilotDesignC has no engine or intercept iff nothing is missing", {
  expect_equal(design_c$engine == "none", design_c$miss_rate == 0)
  expect_equal(is.na(design_c$alpha0), design_c$miss_rate == 0)
  imputed <- design_c[design_c$miss_rate > 0, ]
  expected <- mapply(MissingIntercept, imputed$miss_rate, imputed$delta,
                     imputed$sigma1)
  expect_equal(imputed$alpha0, unname(expected))
  # The same missing fraction gets the same intercept.
  expect_equal(design_c$alpha0[2], design_c$alpha0[3])
  expect_equal(design_c$alpha0[4], design_c$alpha0[5])
  expect_false(design_c$alpha0[2] == design_c$alpha0[4])
})

# -- BlockTable -----------------------------------------------------------

test_that("BlockTable splits 250 replicates into blocks of 100, 100, 50", {
  blocks <- BlockTable(design_c, 250L, block_size = 100L)
  expect_equal(nrow(blocks), 15L)
  for (k in design_c$cell) {
    rows <- blocks[blocks$cell == k, ]
    expect_equal(rows$block, 1:3)
    expect_equal(rows$n_rep_block, c(100, 100, 50))
    expect_equal(sum(rows$n_rep_block), 250)
  }
})

test_that("BlockTable's seed is 20261030 + 1000 * cell + block, all distinct", {
  blocks <- BlockTable(design_c, 250L, block_size = 100L)
  expect_equal(blocks$seed, 20261030 + 1000 * blocks$cell + blocks$block)
  expect_false(anyDuplicated(blocks$seed) > 0)
  # The default block size and seed offset are 100 and 20261030.
  default <- BlockTable(design_c, 250L)
  expect_identical(default, blocks)
  # Production: 2,000 per cell in 20 blocks, still all distinct.
  production <- BlockTable(design_c, 2000L)
  expect_equal(nrow(production), 100L)
  expect_true(all(production$n_rep_block == 100))
  expect_false(anyDuplicated(production$seed) > 0)
})

test_that("BlockTable keeps the cell's design columns and adds three", {
  blocks <- BlockTable(design_c, 250L)
  expect_named(blocks, c(names(design_c), "block", "n_rep_block", "seed"))
  expect_equal(rownames(blocks), as.character(1:15))
  # Each block carries its cell's row of the design.
  for (i in seq_len(nrow(blocks))) {
    expect_equal(blocks[i, names(design_c)],
                 design_c[blocks$cell[i], ], ignore_attr = TRUE)
  }
  # Blocks of a cell are adjacent, in cell order.
  expect_equal(blocks$cell, rep(1:5, each = 3))
})

test_that("BlockTable handles exact multiples, short runs, and other seeds", {
  exact <- BlockTable(design_c, 200L)
  expect_equal(nrow(exact), 10L)
  expect_true(all(exact$n_rep_block == 100))
  short <- BlockTable(design_c, 10L, block_size = 100L)
  expect_equal(nrow(short), 5L)
  expect_true(all(short$n_rep_block == 10))
  expect_equal(short$block, rep(1L, 5))
  other <- BlockTable(design_c, 250L, base_seed = 5L)
  expect_equal(other$seed, 5L + 1000L * other$cell + other$block)
  small <- BlockTable(design_c[2, ], 7L, block_size = 3L)
  expect_equal(small$n_rep_block, c(3, 3, 1))
  expect_equal(small$seed, 20261030 + 2000 + 1:3)
})

# -- RunReplicateC --------------------------------------------------------

test_that("RunReplicateC returns one row with the documented columns", {
  set.seed(101)
  out <- SmallReplicateC(SmallCellC(2))
  expect_s3_class(out, "data.frame")
  expect_equal(nrow(out), 1L)
  expect_named(out, replicate_columns_c)
})

test_that("RunReplicateC's coverage columns are logical, the rest numeric", {
  set.seed(102)
  out <- SmallReplicateC(SmallCellC(2))
  for (nm in logical_columns_c) {
    expect_type(out[[nm]], "logical")
    expect_false(is.na(out[[nm]]), info = nm)
  }
  for (nm in setdiff(replicate_columns_c, logical_columns_c)) {
    expect_true(is.numeric(out[[nm]]), info = nm)
    expect_true(is.finite(out[[nm]]), info = nm)
  }
})

test_that("RunReplicateC's index, correction, and truth obey identities", {
  cell <- SmallCellC(2)
  truth <- MarkerTruth(cell$delta, cell$sigma1)
  for (seed in 103:108) {
    set.seed(seed)
    out <- SmallReplicateC(cell, truth)
    # The maximum of the pooled curve is at least its value at the cutoff.
    expect_gte(out$apparent, out$apparent_at_c_hat - 1e-12)
    # The mean of the per-dataset maxima is at least the maximum of the
    # mean.
    expect_gte(out$gap, -1e-12)
    # corrected = value at the cutoff minus the mean bootstrap optimism.
    expect_equal(out$corrected_20, out$apparent_at_c_hat - out$optimism_20)
    expect_equal(out$corrected_2, out$apparent_at_c_hat - out$optimism_2)
    # The true curve at the chosen cutoff cannot beat the true maximum.
    expect_equal(out$j_at_c_hat,
                 TrueYouden(out$c_hat, truth$delta, truth$sigma1))
    expect_lte(out$j_at_c_hat, truth$j_star + 1e-12)
    expect_true(out$miss_frac >= 0 && out$miss_frac <= 1)
  }
})

test_that("RunReplicateC's grid, widths, and critical values are sensible", {
  cell <- SmallCellC(2)
  truth <- MarkerTruth(cell$delta, cell$sigma1)
  for (seed in 109:112) {
    set.seed(seed)
    out <- SmallReplicateC(cell, truth)
    expect_lt(out$grid_lo, out$grid_hi)
    expect_equal(out$c_star_in_grid,
                 truth$c_star >= out$grid_lo && truth$c_star <= out$grid_hi)
    widths <- c(out$width_pointwise, out$width_rubin, out$width_boot,
                out$width_hybrid)
    expect_true(all(widths > 0))
    # Simultaneous critical values are well above a one-sided normal
    # quantile.
    expect_gt(out$q_rubin, 1.5)
    expect_gt(out$q_boot, 1)
    expect_gt(out$q_hybrid, 1)
    expect_gt(out$q_comp_boot, 0)
    expect_gt(out$q_comp_hybrid, 0)
  }
})

test_that("RunReplicateC's set lengths are non-negative step multiples", {
  cell <- SmallCellC(2)
  for (seed in 113:118) {
    set.seed(seed)
    out <- SmallReplicateC(cell)
    width <- out$grid_hi - out$grid_lo
    step <- width / 8
    lens <- c(out$bandset_boot_length, out$bandset_hybrid_length,
              out$compset_boot_length, out$compset_hybrid_length)
    expect_true(all(lens >= 0))
    # Length is points times step, so at most K steps: the grid's width
    # plus one step.
    expect_true(all(lens <= width + step + 1e-12))
    expect_equal(lens / step, round(lens / step))
    # The comparison-based set always holds the grid's best estimate, so
    # it is never empty.
    expect_gt(out$compset_boot_length, 0)
    expect_gt(out$compset_hybrid_length, 0)
  }
})

test_that("RunReplicateC sees missing values iff the cell has them", {
  set.seed(120)
  imputed <- SmallReplicateC(SmallCellC(2))
  expect_gt(imputed$miss_frac, 0)
  set.seed(120)
  null <- SmallReplicateC(SmallCellC(1))
  expect_equal(null$miss_frac, 0)
})

test_that("RunReplicateC with no imputation has a gap of exactly zero", {
  cell <- SmallCellC(1)
  expect_equal(cell$engine, "none")
  for (seed in 121:124) {
    set.seed(seed)
    out <- SmallReplicateC(cell)
    expect_identical(out$gap, 0)
    # All datasets are the same, so the per-dataset cutoff is the pooled one.
    expect_identical(out$c_p2, out$c_hat)
    expect_gte(out$apparent, out$apparent_at_c_hat - 1e-12)
  }
})

test_that("RunReplicateC runs for every engine and missing fraction", {
  for (k in 3:5) {
    set.seed(130 + k)
    out <- SmallReplicateC(SmallCellC(k))
    expect_equal(nrow(out), 1L)
    expect_named(out, replicate_columns_c)
    expect_gt(out$miss_frac, 0)
    expect_gte(out$gap, -1e-12)
  }
})

test_that("RunReplicateC is reproducible given the seed", {
  cell <- SmallCellC(2)
  set.seed(140)
  a <- SmallReplicateC(cell)
  set.seed(140)
  b <- SmallReplicateC(cell)
  expect_identical(a, b)
  set.seed(141)
  expect_false(identical(a$c_hat, SmallReplicateC(cell)$c_hat))
})

# -- RunDataCell with RunReplicateC ---------------------------------------

test_that("RunDataCell collects RunReplicateC rows, labelled", {
  block <- SmallBlockC(2)
  out <- RunSmallCellC(block, 2)
  expect_equal(nrow(out), 2L)
  expect_true(all(c("rep", "cell") %in% names(out)))
  expect_equal(out$rep, 1:2)
  expect_equal(out$cell, rep(2L, 2))
  expect_true(all(replicate_columns_c %in% names(out)))
  expect_gte(attr(out, "seconds"), 0)
})

test_that("RunDataCell with RunReplicateC is reproducible from the seed", {
  block <- SmallBlockC(2)
  set.seed(1)
  a <- RunSmallCellC(block, 2)
  set.seed(999)
  runif(10)
  b <- RunSmallCellC(block, 2)
  attr(a, "seconds") <- NULL
  attr(b, "seconds") <- NULL
  expect_identical(a, b)
  other <- block
  other$seed <- block$seed + 1L
  d <- RunSmallCellC(other, 2)
  attr(d, "seconds") <- NULL
  expect_false(identical(a$c_hat, d$c_hat))
})

test_that("RunDataCell runs RunReplicateC under L'Ecuyer-CMRG", {
  old <- RNGkind()
  on.exit(RNGkind(old[1], old[2], old[3]))
  seen <- NULL
  block <- SmallBlockC(2, 1L)
  RunDataCell(block, 1, replicate_fun = function(cell, truth) {
    seen <<- RNGkind()[1]
    SmallReplicateC(cell, truth)
  })
  expect_identical(seen, "L'Ecuyer-CMRG")
})

test_that("RunDataCell of the no-missing cell has gap 0 in every replicate", {
  out <- RunSmallCellC(SmallBlockC(1, 3L), 3)
  expect_equal(nrow(out), 3L)
  expect_identical(out$gap, rep(0, 3))
  expect_identical(out$miss_frac, rep(0, 3))
})
