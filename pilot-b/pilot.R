# The re-pilot (pilot-b/preregistration.md, with its amendment): 10 data
# cells at 250 per group, the empirical estimator, three bands, the
# near-optimal sets, and the bootstrap-then-impute optimism correction.
#
# Run from the project root:
#   Rscript pilot-b/pilot.R timing   # ten replicates of every cell, timed
#   Rscript pilot-b/pilot.R          # the re-pilot
#
# Writes to pilot-b/results/: known_answers.rds, timing.rds (timing mode),
# pilot_replicates.rds (per replicate, not committed), cell_summaries.rds
# and .csv, pilot.log, run_info.rds, and session_info.txt.

devtools::load_all(quiet = TRUE)
library(parallel)

n_rep <- 500L      # set from the timing run against the one-hour time box
n_workers <- 3L    # at most three cores, counting the workers
timing_workers <- 2L  # the timing run leaves a core for other work
set.seed(20261029)

args <- commandArgs(trailingOnly = TRUE)
timing_only <- "timing" %in% args
results_dir <- here::here("pilot-b", "results")
dir.create(results_dir, showWarnings = FALSE)
log_file <- file.path(results_dir,
                      if (timing_only) "timing.log" else "pilot.log")
cat(format(Sys.time()), "start,", if (timing_only) "timing" else "pilot",
    "\n", file = log_file)

# Known-answer checks first: a failure stops the run before any cell.
known <- KnownAnswerChecksB()
saveRDS(known, file.path(results_dir, "known_answers.rds"))
if (!all(known$pass)) stop("a known-answer check failed")

design <- PilotDesignB()

blas_env <- c(VECLIB_MAXIMUM_THREADS = "1", OPENBLAS_NUM_THREADS = "1",
              OMP_NUM_THREADS = "1", MKL_NUM_THREADS = "1")
do.call(Sys.setenv, as.list(blas_env))
cl <- makePSOCKcluster(if (timing_only) timing_workers else n_workers)
invisible(clusterCall(cl, function(lib, env, root) {
  .libPaths(lib)
  do.call(Sys.setenv, as.list(env))
  suppressMessages(devtools::load_all(root, quiet = TRUE))
  NULL
}, .libPaths(), blas_env, here::here()))

RunLogged <- function(cell, n_rep, log_file) {
  cat(format(Sys.time()), "cell", cell$cell, "started\n", file = log_file,
      append = TRUE)
  out <- RunDataCell(cell, n_rep, replicate_fun = RunReplicateB)
  cat(format(Sys.time()), "cell", cell$cell, "done in",
      round(attr(out, "seconds")), "s\n", file = log_file, append = TRUE)
  list(reps = out, seconds = attr(out, "seconds"))
}

# One cell per task, longest first (the first pilot's lesson).
cells <- split(design, design$cell)
if (timing_only) {
  timing_reps <- 10L
  runs <- parLapplyLB(cl, cells, RunLogged, n_rep = timing_reps,
                      log_file = log_file, chunk.size = 1)
  stopCluster(cl)
  per_rep <- vapply(runs, function(r) r$seconds, numeric(1)) / timing_reps
  timing <- data.frame(design[, c("cell", "shape", "miss_rate", "engine")],
                       seconds_per_rep = per_rep)
  ProjectWall <- function(cell_seconds) {
    loads <- numeric(n_workers)
    for (s in sort(cell_seconds, decreasing = TRUE)) {
      loads[which.min(loads)] <- loads[which.min(loads)] + s
    }
    max(loads)
  }
  projection <- data.frame(
    n_rep = c(100L, 300L, 500L),
    minutes = vapply(c(100, 300, 500), function(r) {
      ProjectWall(per_rep * r) / 60
    }, numeric(1)))
  saveRDS(list(timing = timing, projection = projection,
               timing_reps = timing_reps, n_workers = n_workers,
               date = Sys.time()), file.path(results_dir, "timing.rds"))
  print(timing, row.names = FALSE)
  print(projection, row.names = FALSE)
  quit(save = "no")
}

start <- Sys.time()
tm <- readRDS(file.path(results_dir, "timing.rds"))$timing
cell_order <- order(tm$seconds_per_rep[match(design$cell, tm$cell)],
                    decreasing = TRUE)
runs <- parLapplyLB(cl, cells[cell_order], RunLogged, n_rep = n_rep,
                    log_file = log_file, chunk.size = 1)
stopCluster(cl)
runtime_minutes <- as.numeric(difftime(Sys.time(), start, units = "mins"))

replicates <- do.call(rbind, lapply(runs, function(r) r$reps))
replicates <- replicates[order(replicates$cell, replicates$rep), ]
rownames(replicates) <- NULL
cell_seconds <- data.frame(
  cell = vapply(runs, function(r) r$reps$cell[1], numeric(1)),
  seconds = vapply(runs, function(r) r$seconds, numeric(1)))
saveRDS(replicates, file.path(results_dir, "pilot_replicates.rds"))

summaries <- SummarizeAllCellsB(replicates, design)
saveRDS(summaries, file.path(results_dir, "cell_summaries.rds"))
utils::write.csv(summaries, file.path(results_dir, "cell_summaries.csv"),
                 row.names = FALSE)

# The base cell and its normal twin, small enough to commit, for the
# report's figures of replicate-level results.
keep <- design$cell[design$shape == "sharp" & design$miss_rate == 0.4]
saveRDS(replicates[replicates$cell %in% keep, ],
        file.path(results_dir, "base_cell_points.rds"))

saveRDS(list(run = "pilot", n_rep = n_rep, n_cells = nrow(design),
             date = Sys.time(),
             note = paste("Re-pilot (pilot-b): bands, near-optimal sets,",
                          "and the optimism correction"),
             n_rep_production = NA_integer_,
             runtime_minutes = runtime_minutes, cell_seconds = cell_seconds,
             n_workers = n_workers, blas_env = blas_env,
             session = utils::sessionInfo()),
        file.path(results_dir, "run_info.rds"))
writeLines(utils::capture.output(utils::sessionInfo()),
           file.path(results_dir, "session_info.txt"))
cat(format(Sys.time()), "finished in", round(runtime_minutes, 1),
    "minutes\n", file = log_file, append = TRUE)
