# The simulation study, as protocol.md sets it: 44 cells in five arms, the
# replicate function RunReplicateC() (the procedure MiYoudenInference()
# with the truth), seeded blocks of 100 replicates on PSOCK workers.
#
# Run from the project root:
#   Rscript analysis/01_simulation.R timing       # ten replicates per cell
#   Rscript analysis/01_simulation.R quick        # the full design, n_rep_quick
#   Rscript analysis/01_simulation.R production   # n_rep_production
# An optional second argument sets the number of workers (default
# n_workers); seeds are per block, so it does not change the results.
#
# Writes to results/: design.rds, simulation_replicates.rds (per replicate,
# git-ignored), cell_summaries.rds and .csv, simulation.log, timing.rds
# (timing mode), run_info.rds, and session_info.txt.

devtools::load_all(quiet = TRUE)

# ---- parameters ---------------------------------------------------------
shapes <- data.frame(shape = c("sharp", "flat", "separated"),
                     delta = c(2, 1.5, 3), sigma1 = c(1, 2.5, 1))
sharp <- shapes[1, ]
miss_rates <- c(0.2, 0.4, 0.6)
engines <- c("pmm", "norm")
n_imp <- 20L                # imputations of the analysis, L
arms <- list(
  # A: every shape at 250 per group
  main = list(shapes = shapes, n = 250L, miss_rates = miss_rates,
              engines = engines),
  # B: the group-size gradient
  size = list(shapes = sharp, n = c(100L, 1000L), miss_rates = miss_rates,
              engines = engines),
  # C: predictive mean matching with ten donors
  donors = list(shapes = sharp, n = 250L, miss_rates = miss_rates,
                engines = "pmm10", include_null = FALSE),
  # D: complete cases, no imputation
  complete_cases = list(shapes = sharp, n = 250L, miss_rates = miss_rates,
                        engines = "cc", include_null = FALSE),
  # E: 100 cases and 400 controls
  unbalanced = list(shapes = sharp, n = 400L, n_cases = 100L,
                    miss_rates = 0.4, engines = engines))
n_rep_quick <- 100L         # the quick run (step 3.3)
n_rep_production <- 2000L   # protocol.md
block_size <- 100L          # replicates per seeded block
n_workers <- 7L             # the user's allowance of eight cores (D-S2)
base_seed <- 20261101L      # block b of cell k: base_seed + 1000 k + b
timing_reps <- 10L

# ---- run ----------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
mode <- if (length(args)) args[1] else "quick"
stopifnot(mode %in% c("timing", "quick", "production"))
if (length(args) > 1) n_workers <- as.integer(args[2])
set.seed(base_seed)
results_dir <- here::here("results")
log_file <- file.path(results_dir, if (mode == "timing") "timing.log" else
  "simulation.log")
cat(format(Sys.time()), "start,", mode, "\n", file = log_file)

design <- CombineDesigns(lapply(arms, function(a) {
  do.call(SimulationDesign, c(a, list(n_imp = n_imp)))
}))
n_rep <- switch(mode, timing = timing_reps, quick = n_rep_quick,
                production = n_rep_production)
blocks <- BlockTable(design, n_rep,
                     block_size = if (mode == "timing") timing_reps else
                       block_size,
                     base_seed = base_seed)

start <- Sys.time()
out <- RunBlocksParallel(blocks, n_workers, log_file = log_file,
                         partial_file = file.path(results_dir,
                                                  "simulation_partial.rds"))
runtime_minutes <- as.numeric(difftime(Sys.time(), start, units = "mins"))

if (mode == "timing") {
  per_rep <- out$block_seconds$seconds / timing_reps
  timing <- data.frame(design[, c("cell", "shape", "n", "n1", "miss_rate",
                                  "engine")], seconds_per_rep = per_rep)
  saveRDS(list(timing = timing, timing_reps = timing_reps,
               n_workers = n_workers, runtime_minutes = runtime_minutes,
               date = Sys.time()), file.path(results_dir, "timing.rds"))
  print(timing, row.names = FALSE)
  quit(save = "no")
}

saveRDS(design, file.path(results_dir, "design.rds"))
saveRDS(out$replicates, file.path(results_dir,
                                  "simulation_replicates.rds"))
summaries <- SummarizeStudy(out$replicates, design)
saveRDS(summaries, file.path(results_dir, "cell_summaries.rds"))
utils::write.csv(summaries, file.path(results_dir, "cell_summaries.csv"),
                 row.names = FALSE)
saveRDS(list(run = mode, n_rep = n_rep, n_cells = nrow(design),
             date = Sys.time(),
             note = "Simulation study, analysis/01_simulation.R",
             n_rep_production = n_rep_production,
             runtime_minutes = runtime_minutes,
             block_seconds = out$block_seconds, n_workers = n_workers,
             blas_env = BlasPinned(), session = utils::sessionInfo()),
        file.path(results_dir, "run_info.rds"))
writeLines(utils::capture.output(utils::sessionInfo()),
           file.path(results_dir, "session_info.txt"))
cat(format(Sys.time()), "finished in", round(runtime_minutes, 1),
    "minutes\n", file = log_file, append = TRUE)
