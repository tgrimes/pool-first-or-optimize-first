# Pilot-c (pilot-c/preregistration.md): five sharp-shape cells at 250 per
# group, the bootstrap and hybrid bands, the band-based and comparison-based
# near-optimal sets, and the optimism correction with 20 and with 2
# imputations per resample. Replicates run in seeded blocks of 100.
#
# Run from the project root:
#   Rscript pilot-c/pilot.R timing   # ten replicates of every cell, timed
#   Rscript pilot-c/pilot.R          # pilot-c
#
# Writes to pilot-c/results/: known_answers.rds, timing.rds (timing mode),
# pilot_replicates.rds (per replicate, not committed), cell_summaries.rds
# and .csv, base_cell_points.rds, pilot.log, run_info.rds, session_info.txt.

devtools::load_all(quiet = TRUE)
library(parallel)

n_rep <- 1300L     # from the timing run: 2,000 projected at 88 minutes (D2)
block_size <- 100L
n_workers <- 7L    # the user's allowance for pilot-c (rules.md says 3)
set.seed(20261030)

args <- commandArgs(trailingOnly = TRUE)
timing_only <- "timing" %in% args
results_dir <- here::here("pilot-c", "results")
dir.create(results_dir, showWarnings = FALSE)
log_file <- file.path(results_dir,
                      if (timing_only) "timing.log" else "pilot.log")
cat(format(Sys.time()), "start,", if (timing_only) "timing" else "pilot",
    "\n", file = log_file)

known <- KnownAnswerChecksC()
saveRDS(known, file.path(results_dir, "known_answers.rds"))
if (!all(known$pass)) stop("a known-answer check failed")

design <- PilotDesignC()
blas_env <- c(VECLIB_MAXIMUM_THREADS = "1", OPENBLAS_NUM_THREADS = "1",
              OMP_NUM_THREADS = "1", MKL_NUM_THREADS = "1")
do.call(Sys.setenv, as.list(blas_env))
cl <- makePSOCKcluster(n_workers)
invisible(clusterCall(cl, function(lib, env, root) {
  .libPaths(lib)
  do.call(Sys.setenv, as.list(env))
  suppressMessages(devtools::load_all(root, quiet = TRUE))
  NULL
}, .libPaths(), blas_env, here::here()))

RunLogged <- function(block, log_file) {
  label <- paste0("cell ", block$cell, " block ", block$block)
  cat(format(Sys.time()), label, "started\n", file = log_file, append = TRUE)
  out <- RunDataCell(block, block$n_rep_block, replicate_fun = RunReplicateC)
  out$block <- block$block
  cat(format(Sys.time()), label, "done in", round(attr(out, "seconds")),
      "s\n", file = log_file, append = TRUE)
  list(reps = out, seconds = attr(out, "seconds"))
}

if (timing_only) {
  timing_reps <- 10L
  blocks <- BlockTable(design, timing_reps, block_size = timing_reps)
  runs <- parLapplyLB(cl, split(blocks, seq_len(nrow(blocks))), RunLogged,
                      log_file = log_file, chunk.size = 1)
  stopCluster(cl)
  per_rep <- vapply(runs, function(r) r$seconds, numeric(1)) / timing_reps
  timing <- data.frame(design[, c("cell", "miss_rate", "engine")],
                       seconds_per_rep = per_rep)
  projection <- data.frame(
    n_rep = c(1000L, 1500L, 2000L),
    minutes = c(1000, 1500, 2000) * sum(per_rep) / n_workers / 60)
  saveRDS(list(timing = timing, projection = projection,
               timing_reps = timing_reps, n_workers = n_workers,
               date = Sys.time()), file.path(results_dir, "timing.rds"))
  print(timing, row.names = FALSE)
  print(projection, row.names = FALSE)
  quit(save = "no")
}

start <- Sys.time()
blocks <- BlockTable(design, n_rep, block_size = block_size)
runs <- parLapplyLB(cl, split(blocks, seq_len(nrow(blocks))), RunLogged,
                    log_file = log_file, chunk.size = 1)
stopCluster(cl)
runtime_minutes <- as.numeric(difftime(Sys.time(), start, units = "mins"))

replicates <- do.call(rbind, lapply(runs, function(r) r$reps))
replicates <- replicates[order(replicates$cell, replicates$block,
                               replicates$rep), ]
rownames(replicates) <- NULL
block_seconds <- data.frame(
  cell = vapply(runs, function(r) r$reps$cell[1], numeric(1)),
  block = vapply(runs, function(r) r$reps$block[1], numeric(1)),
  seconds = vapply(runs, function(r) r$seconds, numeric(1)))
saveRDS(replicates, file.path(results_dir, "pilot_replicates.rds"))

summaries <- SummarizeAllCellsC(replicates, design)
saveRDS(summaries, file.path(results_dir, "cell_summaries.rds"))
utils::write.csv(summaries, file.path(results_dir, "cell_summaries.csv"),
                 row.names = FALSE)
saveRDS(replicates[replicates$cell %in% c(2, 3), ],
        file.path(results_dir, "base_cell_points.rds"))

saveRDS(list(run = "pilot", n_rep = n_rep, n_cells = nrow(design),
             date = Sys.time(),
             note = paste("Pilot-c: comparison-based sets, matched",
                          "optimism correction, band calibration"),
             n_rep_production = NA_integer_,
             runtime_minutes = runtime_minutes,
             block_seconds = block_seconds, n_workers = n_workers,
             blas_env = blas_env, session = utils::sessionInfo()),
        file.path(results_dir, "run_info.rds"))
writeLines(utils::capture.output(utils::sessionInfo()),
           file.path(results_dir, "session_info.txt"))
cat(format(Sys.time()), "finished in", round(runtime_minutes, 1),
    "minutes\n", file = log_file, append = TRUE)
