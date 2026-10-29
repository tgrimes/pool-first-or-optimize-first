# The re-pilot's verdict: applies the pre-registered pass rule
# (pilot-b/preregistration.md, section 5) to the saved cell summaries.
#
# Run from the project root after pilot-b/pilot.R: Rscript pilot-b/verdict.R
# Writes pilot-b/results/verdict.rds, verdict.csv, coverage-by-cell.png, and
# verdict_run_info.rds.

devtools::load_all(quiet = TRUE)
set.seed(20261029)

results_dir <- here::here("pilot-b", "results")
summaries <- readRDS(file.path(results_dir, "cell_summaries.rds"))
run_info <- readRDS(file.path(results_dir, "run_info.rds"))
verdict <- ApplyPassRuleB(summaries)
verdict$run <- run_info$run
verdict$n_rep <- run_info$n_rep
verdict$date <- Sys.time()
saveRDS(verdict, file.path(results_dir, "verdict.rds"))
utils::write.csv(cbind(verdict$criteria, status = verdict$status),
                 file.path(results_dir, "verdict.csv"), row.names = FALSE)

# The spec's plot: simultaneous coverage of the three bands in every cell,
# with +/- 2 MCSE, against 0.95 and the pre-registered limits 0.92 and 0.98.
s <- summaries
s$label <- sprintf("%s %d%% %s", s$shape, round(100 * s$miss_rate),
                   toupper(s$engine))
grDevices::png(file.path(results_dir, "coverage-by-cell.png"), width = 1400,
               height = 900, res = 160)
op <- graphics::par(mar = c(4.2, 9.5, 1, 1))
y <- seq_len(nrow(s))
graphics::plot(s$cover_boot, y, xlim = c(0, 1), yaxt = "n", ylab = "",
               xlab = "Simultaneous coverage over the grid", pch = 19)
graphics::segments(s$cover_boot - 2 * s$cover_boot_mcse, y,
                   s$cover_boot + 2 * s$cover_boot_mcse, y)
graphics::points(s$cover_rubin, y, pch = 2, col = "#2c7fb8")
graphics::points(s$cover_pointwise, y, pch = 4, col = "#d95f02")
graphics::abline(v = c(0.92, 0.95, 0.98), lty = c(2, 1, 2), col = "grey50")
graphics::axis(2, at = y, labels = s$label, las = 1, cex.axis = 0.75)
graphics::legend("bottomleft", c("bootstrap-then-impute", "Rubin sup-t",
                                 "pointwise Rubin"),
                 pch = c(19, 2, 4), col = c("black", "#2c7fb8", "#d95f02"),
                 cex = 0.7, bty = "n")
graphics::par(op)
grDevices::dev.off()

saveRDS(list(run = run_info$run, n_rep = run_info$n_rep,
             n_cells = run_info$n_cells, date = Sys.time(),
             note = "Verdict from pilot-b/results/cell_summaries.rds",
             n_rep_production = run_info$n_rep_production,
             session = utils::sessionInfo()),
        file.path(results_dir, "verdict_run_info.rds"))
cat("status:", verdict$status, "\n")
print(verdict$questions, row.names = FALSE)
