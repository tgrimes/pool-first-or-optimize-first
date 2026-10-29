# The pre-registered pilot (pilot/preregistration.md): 22 data cells, each
# analysed with the empirical and the kernel estimator, R replicates per
# cell, each cell seeded from the design table.
#
# Run from the project root:
#   Rscript pilot/pilot.R timing   # ten replicates of every cell, timed
#   Rscript pilot/pilot.R          # the pilot
#
# Writes to pilot/results/: known_answers.rds, timing.rds (timing mode),
# pilot_replicates.rds (per replicate, not committed), cell_summaries.rds
# and .csv (per cell, with Monte Carlo standard errors),
# base_cell_points.rds, pilot.log, run_info.rds, and session_info.txt.

devtools::load_all(quiet = TRUE)
library(parallel)

n_rep <- 500L      # set from the timing run against the one-hour time box
n_workers <- 3L    # at most three cores, counting the workers
timing_workers <- 2L  # the timing run leaves a core for other work
set.seed(20261028)

args <- commandArgs(trailingOnly = TRUE)
timing_only <- "timing" %in% args
results_dir <- here::here("pilot", "results")
dir.create(results_dir, showWarnings = FALSE)
log_file <- file.path(results_dir,
                      if (timing_only) "timing.log" else "pilot.log")
cat(format(Sys.time()), "start,", if (timing_only) "timing" else "pilot",
    "\n", file = log_file)

# Known-answer checks first: a failure stops the run before any cell.
known <- KnownAnswerChecks()
saveRDS(known, file.path(results_dir, "known_answers.rds"))
if (!all(known$pass)) stop("a known-answer check failed")

design <- PilotDesign()

# One thread of BLAS in every worker; workers inherit these variables.
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
  out <- RunDataCell(cell, n_rep)
  cat(format(Sys.time()), "cell", cell$cell, "done in",
      round(attr(out, "seconds")), "s\n", file = log_file, append = TRUE)
  list(reps = out, seconds = attr(out, "seconds"))
}

if (timing_only) {
  timing_reps <- 10L
  runs <- parLapplyLB(cl, split(design, design$cell), RunLogged,
                      n_rep = timing_reps, log_file = log_file)
  stopCluster(cl)
  per_rep <- vapply(runs, function(r) r$seconds, numeric(1)) / timing_reps
  timing <- data.frame(design[, c("cell", "shape", "miss_rate", "n",
                                  "engine", "n_imp")],
                       seconds_per_rep = per_rep)
  # Projected wall time: cells scheduled longest first on n_workers.
  ProjectWall <- function(cell_seconds) {
    loads <- numeric(n_workers)
    for (s in sort(cell_seconds, decreasing = TRUE)) {
      loads[which.min(loads)] <- loads[which.min(loads)] + s
    }
    max(loads)
  }
  projection <- data.frame(
    n_rep = c(100L, 200L, 300L, 400L, 500L),
    minutes = vapply(c(100, 200, 300, 400, 500), function(r) {
      ProjectWall(per_rep * r) / 60
    }, numeric(1)))
  saveRDS(list(timing = timing, projection = projection,
               timing_reps = timing_reps, n_workers = n_workers,
               date = Sys.time()), file.path(results_dir, "timing.rds"))
  print(timing, row.names = FALSE)
  print(projection, row.names = FALSE)
  quit(save = "no")
}

# The pilot: longest cells first, so that the three workers finish together.
start <- Sys.time()
cell_order <- order(design$n * design$n_imp *
                      ifelse(design$engine == "nn", 3, 1), decreasing = TRUE)
runs <- parLapplyLB(cl, split(design, design$cell)[cell_order], RunLogged,
                    n_rep = n_rep, log_file = log_file)
stopCluster(cl)
runtime_minutes <- as.numeric(difftime(Sys.time(), start, units = "mins"))

replicates <- do.call(rbind, lapply(runs, function(r) r$reps))
replicates <- replicates[order(replicates$cell, replicates$rep,
                               replicates$estimator), ]
rownames(replicates) <- NULL
cell_seconds <- data.frame(
  cell = vapply(runs, function(r) r$reps$cell[1], numeric(1)),
  seconds = vapply(runs, function(r) r$seconds, numeric(1)))
saveRDS(replicates, file.path(results_dir, "pilot_replicates.rds"))

summaries <- SummarizeAllCells(replicates, design)
saveRDS(summaries, file.path(results_dir, "cell_summaries.rds"))
utils::write.csv(summaries, file.path(results_dir, "cell_summaries.csv"),
                 row.names = FALSE)

# The base cell's replicates, small enough to commit, for the report's
# scatter of the gap against the spread of the cutoffs.
base_cell <- design$cell[design$base]
saveRDS(replicates[replicates$cell == base_cell, ],
        file.path(results_dir, "base_cell_points.rds"))

saveRDS(list(run = "pilot", n_rep = n_rep, n_cells = nrow(design),
             n_analysis_cells = nrow(summaries), date = Sys.time(),
             note = paste("Pre-registered pilot; 22 data cells, each",
                          "analysed with the empirical and kernel",
                          "estimators"),
             n_rep_production = NA_integer_,
             runtime_minutes = runtime_minutes, cell_seconds = cell_seconds,
             n_workers = n_workers, blas_env = blas_env,
             session = utils::sessionInfo()),
        file.path(results_dir, "run_info.rds"))
writeLines(utils::capture.output(utils::sessionInfo()),
           file.path(results_dir, "session_info.txt"))
cat(format(Sys.time()), "finished in", round(runtime_minutes, 1),
    "minutes\n", file = log_file, append = TRUE)
