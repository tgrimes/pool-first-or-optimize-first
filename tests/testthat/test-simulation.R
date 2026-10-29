test_that("SimulationDesign puts the complete cell first in each shape and size", {
  shapes <- data.frame(shape = c("sharp", "flat"), delta = c(2, 1.5),
                       sigma1 = c(1, 2.5))
  d <- SimulationDesign(shapes, n = c(100L, 250L), miss_rates = c(0.2, 0.4),
                        engines = c("pmm", "norm"))
  expect_equal(nrow(d), 2 * 2 * (1 + 2 * 2))
  expect_equal(d$cell, seq_len(nrow(d)))
  first <- d[!duplicated(d[, c("shape", "n")]), ]
  expect_true(all(first$engine == "none" & first$miss_rate == 0))
  expect_true(all(is.na(d$alpha0[d$miss_rate == 0])))
  expect_true(all(!is.na(d$alpha0[d$miss_rate > 0])))
  expect_equal(sum(d$base), 1)
  base <- d[d$base, ]
  expect_equal(base$shape, "sharp")
  expect_equal(base$n, 250L)
  expect_equal(base$miss_rate, 0.4)
  expect_equal(base$engine, "pmm")
  within <- d[d$shape == "sharp" & d$n == 100L, ]
  expect_equal(within$engine, c("none", "pmm", "norm", "pmm", "norm"))
  expect_equal(within$miss_rate, c(0, 0.2, 0.2, 0.4, 0.4))
})

test_that("SimulationDesign's intercepts give the target missing fraction", {
  d <- SimulationDesign(data.frame(shape = "sharp", delta = 2, sigma1 = 1),
                        n = 250L, miss_rates = 0.6, engines = "pmm")
  expect_equal(d$alpha0[2], MissingIntercept(0.6, 2, 1))
})

test_that("CellLabel names only the factors that vary", {
  d <- PilotDesignC()
  expect_equal(CellLabel(d), c("no missing", "40% PMM", "40% normal",
                               "60% PMM", "60% normal"))
  shapes <- data.frame(shape = c("sharp", "flat"), delta = c(2, 1.5),
                       sigma1 = c(1, 2.5))
  d2 <- SimulationDesign(shapes, n = c(100L, 250L), miss_rates = 0.4,
                         engines = "pmm")
  lab <- CellLabel(d2)
  expect_equal(lab[1], "sharp, n = 100, no missing")
  expect_equal(lab[nrow(d2)], "flat, n = 250, 40% PMM")
})

test_that("RunBlock equals RunDataCell with the block number added", {
  ToyReplicate <- function(cell, truth) {
    data.frame(x = stats::runif(1), n = cell$n)
  }
  block <- BlockTable(PilotDesignC(), 4L, block_size = 2L)[3, ]
  kind <- RNGkind()
  on.exit(RNGkind(kind[1], kind[2], kind[3]))
  got <- RunBlock(block, replicate_fun = ToyReplicate)
  want <- RunDataCell(block, block$n_rep_block, replicate_fun = ToyReplicate)
  expect_equal(got$x, want$x)
  expect_equal(got$block, rep(block$block, block$n_rep_block))
  expect_equal(got$cell, rep(block$cell, block$n_rep_block))
})

test_that("RunBlock appends start and end lines to a log file", {
  ToyReplicate <- function(cell, truth) data.frame(x = 1)
  block <- BlockTable(PilotDesignC(), 1L, block_size = 1L)[1, ]
  log_file <- tempfile()
  kind <- RNGkind()
  on.exit(RNGkind(kind[1], kind[2], kind[3]))
  RunBlock(block, replicate_fun = ToyReplicate, log_file = log_file)
  lines <- readLines(log_file)
  expect_length(lines, 2)
  expect_match(lines[1], "cell 1 block 1 started")
  expect_match(lines[2], "cell 1 block 1 done in")
})

test_that("CollectBlocks orders rows by cell, block, and replicate", {
  Make <- function(cell, block, seconds) {
    list(reps = data.frame(cell = cell, block = block, rep = 2:1),
         seconds = seconds)
  }
  out <- CollectBlocks(list(Make(2, 1, 5), Make(1, 2, 3), Make(1, 1, 4)))
  expect_equal(out$replicates$cell, c(1, 1, 1, 1, 2, 2))
  expect_equal(out$replicates$block, c(1, 1, 2, 2, 1, 1))
  expect_equal(out$replicates$rep, c(1, 2, 1, 2, 1, 2))
  expect_equal(out$block_seconds$seconds, c(5, 3, 4))
  expect_equal(rownames(out$replicates), as.character(1:6))
})

test_that("BlasPinned pins every BLAS to one thread", {
  b <- BlasPinned()
  expect_true(all(b == "1"))
  expect_true("VECLIB_MAXIMUM_THREADS" %in% names(b))
})

test_that("RunBlocksParallel runs every block on a worker, seeded per block", {
  root <- normalizePath(test_path("..", ".."), mustWork = FALSE)
  skip_if_not(file.exists(file.path(root, "DESCRIPTION")),
              "the package source is not two levels up (R CMD check)")
  ToyReplicate <- function(cell, truth) data.frame(x = stats::runif(1))
  blocks <- BlockTable(PilotDesignC()[1:2, ], 4L, block_size = 2L)
  log_file <- tempfile()
  out <- RunBlocksParallel(blocks, 1L, log_file = log_file, root = root,
                           replicate_fun = ToyReplicate)
  expect_equal(nrow(out$replicates), 8)
  expect_equal(nrow(out$block_seconds), 4)
  expect_length(readLines(log_file), 8)
  kind <- RNGkind()
  on.exit(RNGkind(kind[1], kind[2], kind[3]))
  serial <- CollectBlocks(lapply(split(blocks, seq_len(nrow(blocks))),
                                 function(b) {
    reps <- RunBlock(b, replicate_fun = ToyReplicate)
    list(reps = reps, seconds = attr(reps, "seconds"))
  }))
  expect_equal(out$replicates$x, serial$replicates$x)
})
