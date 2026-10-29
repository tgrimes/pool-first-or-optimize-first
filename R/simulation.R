# The simulation study's design table and the code that runs its seeded
# blocks of replicates on PSOCK workers. analysis/01_simulation.R calls
# these; the replicate itself is RunReplicateC().

#' Design table of the simulation study
#'
#' One row per data cell. For each shape and group size, the cell without
#' missing values comes first, then every missing fraction crossed with every
#' imputation engine, the engines varying fastest. With pilot-c's levels
#' (the sharp shape, 250 per group, 40% and 60% missing, predictive mean
#' matching and normal imputation) the table equals `PilotDesignC()`.
#'
#' @param shapes A data frame with `shape`, `delta`, and `sigma1`.
#' @param n Subjects per group (one or more).
#' @param miss_rates Missing fractions above zero.
#' @param engines Imputation engines, as `ImputeWith()` names them.
#' @param n_imp Number of imputations \eqn{L} of the analysis.
#' @param base A list naming the base cell's `shape`, `n`, `miss_rate`, and
#'   `engine`.
#' @return A data frame with `cell`, `shape`, `delta`, `sigma1`,
#'   `miss_rate`, `alpha0`, `n`, `engine`, `n_imp`, `base`.
#' @export
SimulationDesign <- function(shapes, n, miss_rates, engines, n_imp = 20L,
                             base = list(shape = "sharp", n = 250L,
                                         miss_rate = 0.4, engine = "pmm")) {
  rows <- list()
  for (i in seq_len(nrow(shapes))) {
    for (size in n) {
      cells <- rbind(
        data.frame(miss_rate = 0, engine = "none"),
        expand.grid(engine = engines, miss_rate = miss_rates,
                    stringsAsFactors = FALSE)[, c("miss_rate", "engine")])
      cells$shape <- shapes$shape[i]
      cells$delta <- shapes$delta[i]
      cells$sigma1 <- shapes$sigma1[i]
      cells$n <- as.integer(size)
      rows[[length(rows) + 1]] <- cells
    }
  }
  design <- do.call(rbind, rows)
  design$cell <- seq_len(nrow(design))
  design$n_imp <- as.integer(n_imp)
  design$alpha0 <- NA_real_
  for (i in which(design$miss_rate > 0)) {
    design$alpha0[i] <- MissingIntercept(design$miss_rate[i],
                                         design$delta[i], design$sigma1[i])
  }
  design$base <- design$shape == base$shape & design$n == base$n &
    design$miss_rate == base$miss_rate & design$engine == base$engine
  rownames(design) <- NULL
  design[, c("cell", "shape", "delta", "sigma1", "miss_rate", "alpha0", "n",
             "engine", "n_imp", "base")]
}

#' Plain labels for the cells of a design table
#'
#' @param design A design table with `shape`, `n`, `miss_rate`, `engine`.
#' @return A character vector, one label per cell, naming only the factors
#'   that vary across the table.
#' @export
CellLabel <- function(design) {
  engine <- c(none = "complete", pmm = "PMM", norm = "normal",
              nn = "nearest neighbour")[design$engine]
  parts <- list()
  if (length(unique(design$shape)) > 1) parts$shape <- design$shape
  if (length(unique(design$n)) > 1) parts$n <- paste0("n = ", design$n)
  parts$miss <- ifelse(design$miss_rate > 0,
                       paste0(round(100 * design$miss_rate), "% ", engine),
                       "no missing")
  do.call(paste, c(unname(parts), sep = ", "))
}

#' Run one seeded block of replicates
#'
#' @param block One row of `BlockTable()`.
#' @param replicate_fun The function that runs one replicate.
#' @param log_file Optional file to which the block's start and end are
#'   appended.
#' @return The block's per-replicate rows, with `cell`, `block`, and `rep`,
#'   and the elapsed seconds as the attribute `seconds`.
#' @export
RunBlock <- function(block, replicate_fun = RunReplicateC, log_file = NULL) {
  label <- paste0("cell ", block$cell, " block ", block$block)
  if (!is.null(log_file)) {
    cat(format(Sys.time()), label, "started\n", file = log_file,
        append = TRUE)
  }
  out <- RunDataCell(block, block$n_rep_block, replicate_fun = replicate_fun)
  out$block <- block$block
  if (!is.null(log_file)) {
    cat(format(Sys.time()), label, "done in", round(attr(out, "seconds")),
        "s\n", file = log_file, append = TRUE)
  }
  out
}

#' Environment variables that pin the BLAS to one thread
#'
#' @return A named character vector.
#' @export
BlasPinned <- function() {
  c(VECLIB_MAXIMUM_THREADS = "1", OPENBLAS_NUM_THREADS = "1",
    OMP_NUM_THREADS = "1", MKL_NUM_THREADS = "1")
}

#' Run seeded blocks on PSOCK workers
#'
#' Starts `n_workers` PSOCK workers with the BLAS pinned to one thread in
#' each, loads the package in each from `root`, and runs one block per task
#' (`parLapplyLB()` with `chunk.size = 1`, since blocks differ in cost).
#' Each block seeds its own generator, so the result does not depend on the
#' worker that runs it.
#'
#' @param blocks Output of `BlockTable()`.
#' @param n_workers Number of workers (the cap in `rules.md` is three).
#' @param log_file Optional log file.
#' @param root The project root, from which the workers load the package.
#' @param replicate_fun The function that runs one replicate.
#' @return A list with `replicates` (all rows, ordered by cell, block, and
#'   replicate) and `block_seconds` (one row per block).
#' @export
RunBlocksParallel <- function(blocks, n_workers, log_file = NULL,
                              root = here::here(),
                              replicate_fun = RunReplicateC) {
  do.call(Sys.setenv, as.list(BlasPinned()))
  cl <- parallel::makePSOCKcluster(n_workers)
  on.exit(parallel::stopCluster(cl), add = TRUE)
  invisible(parallel::clusterCall(cl, function(lib, env, path) {
    .libPaths(lib)
    do.call(Sys.setenv, as.list(env))
    suppressMessages(devtools::load_all(path, quiet = TRUE))
    NULL
  }, .libPaths(), BlasPinned(), root))
  tasks <- split(blocks, seq_len(nrow(blocks)))
  runs <- parallel::parLapplyLB(cl, tasks, function(block, log_file, fun) {
    out <- RunBlock(block, replicate_fun = fun, log_file = log_file)
    list(reps = out, seconds = attr(out, "seconds"))
  }, log_file = log_file, fun = replicate_fun, chunk.size = 1)
  CollectBlocks(runs)
}

#' Collect the output of seeded blocks
#'
#' @param runs A list with one element per block, each a list with `reps`
#'   (the block's rows, with `cell` and `block`) and `seconds`.
#' @return A list with `replicates`, ordered by cell, block, and replicate,
#'   and `block_seconds`.
#' @export
CollectBlocks <- function(runs) {
  replicates <- do.call(rbind, lapply(runs, function(r) r$reps))
  replicates <- replicates[order(replicates$cell, replicates$block,
                                 replicates$rep), ]
  rownames(replicates) <- NULL
  block_seconds <- data.frame(
    cell = vapply(runs, function(r) r$reps$cell[1], numeric(1)),
    block = vapply(runs, function(r) r$reps$block[1], numeric(1)),
    seconds = vapply(runs, function(r) r$seconds, numeric(1)))
  list(replicates = replicates, block_seconds = block_seconds)
}
