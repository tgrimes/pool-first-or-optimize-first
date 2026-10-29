# The simulation study (protocol.md). Until the design stop of stage 3 the
# parameter block carries pilot-c's design (pilot-c/preregistration.md);
# protocol.md replaces it with the approved design.
#
# Run from the project root:
#   Rscript analysis/01_simulation.R timing       # ten replicates per cell
#   Rscript analysis/01_simulation.R quick        # the full design, n_rep_quick
#   Rscript analysis/01_simulation.R production   # n_rep_production
#
# Writes to results/: design.rds, simulation_replicates.rds (per replicate,
# git-ignored), cell_summaries.rds and .csv, simulation.log, timing.rds
# (timing mode), run_info.rds, and session_info.txt.

devtools::load_all(quiet = TRUE)

# ---- parameters ---------------------------------------------------------
shapes <- data.frame(shape = "sharp", delta = 2, sigma1 = 1)
n_per_group <- 250L
miss_rates <- c(0.4, 0.6)
engines <- c("pmm", "norm")
n_imp <- 20L                # imputations of the analysis, L
n_rep_quick <- 1300L        # pilot-c's count; set from the timing run
n_rep_production <- 1300L   # set by protocol.md
block_size <- 100L          # replicates per seeded block
n_workers <- 3L             # the core cap of rules.md, section 5
base_seed <- 20261030L      # block b of cell k: base_seed + 1000 k + b
timing_reps <- 10L

# ---- run ----------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
mode <- if (length(args)) args[1] else "quick"
stopifnot(mode %in% c("timing", "quick", "production"))
set.seed(base_seed)
results_dir <- here::here("results")
log_file <- file.path(results_dir, if (mode == "timing") "timing.log" else
  "simulation.log")
cat(format(Sys.time()), "start,", mode, "\n", file = log_file)

design <- SimulationDesign(shapes, n_per_group, miss_rates, engines, n_imp)
n_rep <- switch(mode, timing = timing_reps, quick = n_rep_quick,
                production = n_rep_production)
blocks <- BlockTable(design, n_rep,
                     block_size = if (mode == "timing") timing_reps else
                       block_size,
                     base_seed = base_seed)

start <- Sys.time()
out <- RunBlocksParallel(blocks, n_workers, log_file = log_file)
runtime_minutes <- as.numeric(difftime(Sys.time(), start, units = "mins"))

if (mode == "timing") {
  per_rep <- out$block_seconds$seconds / timing_reps
  timing <- data.frame(design[, c("cell", "shape", "n", "miss_rate",
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
summaries <- SummarizeAllCellsC(out$replicates, design)
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
