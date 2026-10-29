# Acceptance test (workflow/03-manuscript.md, step 1.6): the package's
# functions reproduce pilot-c's saved results from its design and seeds.
# Gated so that R CMD check stays fast:
#   MICUTOFF_ACCEPTANCE=sample  every per-cell summary recomputed from the
#                               saved replicates, and the first replicate of
#                               every seeded block rerun (65 replicates)
#   MICUTOFF_ACCEPTANCE=full    every block rerun (6,500 replicates; about
#                               two hours on three cores) and every per-cell
#                               summary compared
# Run with the BLAS on one thread, as the pilot's workers were:
#   VECLIB_MAXIMUM_THREADS=1 MICUTOFF_ACCEPTANCE=sample \
#     Rscript -e 'devtools::test(filter = "acceptance")'

acceptance <- Sys.getenv("MICUTOFF_ACCEPTANCE")
fixture <- function(name) test_path("fixtures", name)

# The tolerance of PairSe() (issue C1 of the background report, revision
# round 1) changes pilot-c's record where grid points tie: pilot-c kept a
# pair whose difference variance was a rounding error. The fix only drops
# such pairs, so the hybrid comparison critical value, the set's length, and
# whether it holds the best point can only fall; every other column is
# reproduced exactly.
c1_cols <- c("q_comp_hybrid", "compset_hybrid_contains",
             "compset_hybrid_length")
c1_summary_cols <- c("compset_hybrid", "compset_hybrid_mcse",
                     "compset_hybrid_length", "length_ratio_hybrid",
                     "length_ratio_hybrid_mcse", "q_comp_hybrid")

# Pilot-c's record against a rerun under the fix: exact outside the columns
# above, and no rise in them.
ExpectC1Fix <- function(got, want, cols, label) {
  same <- setdiff(names(want), cols)
  expect_equal(got[, same], want[, same], tolerance = 1e-12,
               ignore_attr = TRUE, label = label)
  for (col in intersect(cols, c("q_comp_hybrid", "compset_hybrid_length",
                                "compset_hybrid_contains", "compset_hybrid",
                                "length_ratio_hybrid"))) {
    expect_true(all(got[[col]] <= want[[col]] + 1e-12),
                label = paste(label, col))
  }
}

PilotCDesignTable <- function() {
  SimulationDesign(data.frame(shape = "sharp", delta = 2, sigma1 = 1),
                   n = 250L, miss_rates = c(0.4, 0.6),
                   engines = c("pmm", "norm"), n_imp = 20L)
}

WithSavedRng <- function(code) {
  kind <- RNGkind()
  seed <- if (exists(".Random.seed", globalenv())) {
    get(".Random.seed", globalenv())
  }
  on.exit({
    RNGkind(kind[1], kind[2], kind[3])
    if (!is.null(seed)) assign(".Random.seed", seed, globalenv())
  })
  code
}

test_that("the design table reproduces pilot-c's cells", {
  d <- PilotCDesignTable()
  expect_equal(d[, names(PilotDesignC())], PilotDesignC())
  expect_equal(d$n1, d$n)
})

test_that("every per-cell summary of pilot-c is recomputed exactly", {
  skip_if(acceptance == "", "MICUTOFF_ACCEPTANCE is not set")
  saved <- readRDS(fixture("pilot-c-cell-summaries.rds"))
  reps <- readRDS(fixture("pilot-c-replicates.rds"))
  expect_identical(nrow(reps), 6500L)
  again <- SummarizeAllCellsC(reps, PilotDesignC())
  expect_equal(again, saved, tolerance = 1e-12)
})

test_that("the first replicate of every pilot-c block is reproduced", {
  skip_if(!acceptance %in% c("sample", "full"),
          "MICUTOFF_ACCEPTANCE is not sample or full")
  reps <- readRDS(fixture("pilot-c-replicates.rds"))
  blocks <- BlockTable(PilotCDesignTable(), 1300L, block_size = 100L)
  expect_identical(nrow(blocks), 65L)
  WithSavedRng({
    for (i in seq_len(nrow(blocks))) {
      block <- blocks[i, ]
      block$n_rep_block <- 1L
      got <- RunBlock(block)
      want <- reps[reps$cell == block$cell & reps$block == block$block &
                     reps$rep == 1, ]
      rownames(want) <- NULL
      label <- paste("cell", block$cell, "block", block$block)
      ExpectC1Fix(got[, names(want)], want, c1_cols, label)
      # Where the critical value is unchanged, so is the set.
      if (abs(got$q_comp_hybrid - want$q_comp_hybrid) < 1e-12) {
        expect_equal(got[, c1_cols], want[, c1_cols], tolerance = 1e-12,
                     ignore_attr = TRUE, label = label)
      }
    }
  })
})

test_that("a full rerun of pilot-c reproduces every per-cell summary", {
  skip_if(acceptance != "full", "MICUTOFF_ACCEPTANCE is not full")
  saved <- readRDS(fixture("pilot-c-cell-summaries.rds"))
  design <- PilotDesignC()
  blocks <- BlockTable(PilotCDesignTable(), 1300L, block_size = 100L)
  out <- RunBlocksParallel(blocks, 3L,
                           root = normalizePath(test_path("..", "..")))
  again <- SummarizeAllCellsC(out$replicates, design)
  ExpectC1Fix(again, saved, c1_summary_cols, "pilot-c summaries")
})
