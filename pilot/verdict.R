# The verdict: applies the pre-registered pass rule
# (pilot/preregistration.md, section 5) to the saved cell summaries.
#
# Run from the project root after pilot/pilot.R: Rscript pilot/verdict.R
# Writes pilot/results/verdict.rds, verdict.csv (one row per criterion),
# gap-by-cell.png, and verdict_run_info.rds.

devtools::load_all(quiet = TRUE)
set.seed(20261028)

results_dir <- here::here("pilot", "results")
summaries <- readRDS(file.path(results_dir, "cell_summaries.rds"))
run_info <- readRDS(file.path(results_dir, "run_info.rds"))
verdict <- ApplyPassRule(summaries)
verdict$run <- run_info$run
verdict$n_rep <- run_info$n_rep
verdict$date <- Sys.time()

saveRDS(verdict, file.path(results_dir, "verdict.rds"))
utils::write.csv(cbind(verdict$criteria, status = verdict$status),
                 file.path(results_dir, "verdict.csv"), row.names = FALSE)

# The spec's plot: the mean gap with +/- 2 MCSE in every analysis cell with
# missing values, against the pre-registered thresholds 0.01 and 0.005.
s <- summaries[summaries$miss_rate > 0, ]
s$label <- sprintf("%s %d%% n=%d %s L=%d", s$shape, round(100 * s$miss_rate),
                   s$n, toupper(s$engine), s$n_imp)
s <- s[order(s$estimator, s$engine, s$shape, s$n, s$miss_rate, s$n_imp), ]
grDevices::png(file.path(results_dir, "gap-by-cell.png"), width = 1600,
               height = 1000, res = 160)
op <- graphics::par(mfrow = c(1, 2), mar = c(4.2, 11, 2.2, 1))
for (est in c("empirical", "kernel")) {
  e <- s[s$estimator == est, ]
  y <- seq_len(nrow(e))
  graphics::plot(e$gap, y, xlim = range(0, e$gap + 2 * e$gap_mcse, 0.011),
                 yaxt = "n", ylab = "", xlab = "Mean gap, P2 index - P1 index",
                 pch = ifelse(e$engine == "pmm", 19, 1), main = est)
  graphics::segments(e$gap - 2 * e$gap_mcse, y, e$gap + 2 * e$gap_mcse, y)
  graphics::axis(2, at = y, labels = e$label, las = 1, cex.axis = 0.7)
  graphics::abline(v = c(0.005, 0.01), lty = c(3, 2), col = "grey40")
}
graphics::par(op)
grDevices::dev.off()

saveRDS(list(run = run_info$run, n_rep = run_info$n_rep,
             n_cells = run_info$n_cells, date = Sys.time(),
             note = "Verdict from pilot/results/cell_summaries.rds",
             n_rep_production = run_info$n_rep_production,
             session = utils::sessionInfo()),
        file.path(results_dir, "verdict_run_info.rds"))
cat("status:", verdict$status, "\n")
print(verdict$questions, row.names = FALSE)
