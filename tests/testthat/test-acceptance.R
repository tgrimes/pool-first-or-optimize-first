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
  expect_equal(PilotCDesignTable(), PilotDesignC())
})

test_that("every per-cell summary of pilot-c is recomputed exactly", {
  skip_if(acceptance == "", "MICUTOFF_ACCEPTANCE is not set")
  saved <- readRDS(fixture("pilot-c-cell-summaries.rds"))
  reps <- readRDS(fixture("pilot-c-replicates.rds"))
  expect_identical(nrow(reps), 6500L)
  again <- SummarizeAllCellsC(reps, PilotCDesignTable())
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
      expect_equal(got[, names(want)], want, tolerance = 1e-12,
                   ignore_attr = TRUE,
                   label = paste("cell", block$cell, "block", block$block))
    }
  })
})

test_that("a full rerun of pilot-c reproduces every per-cell summary", {
  skip_if(acceptance != "full", "MICUTOFF_ACCEPTANCE is not full")
  saved <- readRDS(fixture("pilot-c-cell-summaries.rds"))
  design <- PilotCDesignTable()
  blocks <- BlockTable(design, 1300L, block_size = 100L)
  out <- RunBlocksParallel(blocks, 3L,
                           root = normalizePath(test_path("..", "..")))
  again <- SummarizeAllCellsC(out$replicates, design)
  expect_equal(again, saved, tolerance = 1e-12)
})
