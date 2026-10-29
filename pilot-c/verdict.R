# The re-pilot's verdict: applies the pre-registered pass rule
# (pilot-c/preregistration.md, section 5) to the saved cell summaries.
#
# Run from the project root after pilot-c/pilot.R: Rscript pilot-c/verdict.R
# Writes pilot-c/results/verdict.rds, verdict.csv, coverage-by-cell.png, and
# verdict_run_info.rds.

devtools::load_all(quiet = TRUE)
set.seed(20261030)

results_dir <- here::here("pilot-c", "results")
summaries <- readRDS(file.path(results_dir, "cell_summaries.rds"))
run_info <- readRDS(file.path(results_dir, "run_info.rds"))
verdict <- ApplyPassRuleC(summaries)
verdict$run <- run_info$run
verdict$n_rep <- run_info$n_rep
verdict$date <- Sys.time()
saveRDS(verdict, file.path(results_dir, "verdict.rds"))
utils::write.csv(cbind(verdict$criteria, status = verdict$status),
                 file.path(results_dir, "verdict.csv"), row.names = FALSE)

# The spec's plot: coverage of the two candidate bands and their
# comparison-based sets in every cell, with +/- 2 MCSE, against 0.93, 0.95,
# and 0.97.
s <- summaries
s$label <- sprintf("%d%% %s", round(100 * s$miss_rate), toupper(s$engine))
grDevices::png(file.path(results_dir, "coverage-by-cell.png"), width = 1400,
               height = 800, res = 160)
op <- graphics::par(mar = c(4.2, 7, 1, 1))
y <- seq_len(nrow(s))
graphics::plot(s$cover_boot, y - 0.15, xlim = c(0.85, 1), ylim = c(0.5, nrow(s) + 0.5),
               yaxt = "n", ylab = "", xlab = "Coverage", pch = 19)
graphics::segments(s$cover_boot - 2 * s$cover_boot_mcse, y - 0.15,
                   s$cover_boot + 2 * s$cover_boot_mcse, y - 0.15)
graphics::points(s$cover_hybrid, y + 0.15, pch = 17, col = "#2c7fb8")
graphics::segments(s$cover_hybrid - 2 * s$cover_hybrid_mcse, y + 0.15,
                   s$cover_hybrid + 2 * s$cover_hybrid_mcse, y + 0.15,
                   col = "#2c7fb8")
graphics::points(s$compset_boot, y - 0.15, pch = 1)
graphics::points(s$compset_hybrid, y + 0.15, pch = 2, col = "#2c7fb8")
graphics::abline(v = c(0.93, 0.95, 0.97), lty = c(2, 1, 2), col = "grey50")
graphics::axis(2, at = y, labels = s$label, las = 1, cex.axis = 0.8)
graphics::legend("bottomleft", c("bootstrap band", "hybrid band",
                                 "bootstrap set", "hybrid set"),
                 pch = c(19, 17, 1, 2), col = c("black", "#2c7fb8", "black",
                                                "#2c7fb8"),
                 cex = 0.7, bty = "n")
graphics::par(op)
grDevices::dev.off()

saveRDS(list(run = run_info$run, n_rep = run_info$n_rep,
             n_cells = run_info$n_cells, date = Sys.time(),
             note = "Verdict from pilot-c/results/cell_summaries.rds",
             n_rep_production = run_info$n_rep_production,
             session = utils::sessionInfo()),
        file.path(results_dir, "verdict_run_info.rds"))
cat("status:", verdict$status, "\n")
print(verdict$questions, row.names = FALSE)
print(verdict$constructions, row.names = FALSE)
