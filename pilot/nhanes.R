# The application's data, described for the pilot report: the adult
# cotinine cohort of NHANES 2013-2014, 2015-2016, and 2017-2018, the share
# with cotinine missing, the strata of Aim 3, and the full-data Youden curve
# of log cotinine on the simulation's standardized scale. Descriptive only:
# no imputation and no survey weights.
#
# Run from the project root after analysis/00_download.R:
#   Rscript pilot/nhanes.R
# Writes pilot/results/nhanes_summary.rds and nhanes_run_info.rds.

devtools::load_all(quiet = TRUE)
set.seed(20261028)

files <- NhanesFiles()
cycles <- unique(files[, c("cycle", "suffix")])
cohort <- do.call(rbind, lapply(seq_len(nrow(cycles)), function(i) {
  ReadNhanesCycle(here::here("data", "raw"), cycles$suffix[i],
                  cycles$cycle[i])
}))

by_cycle <- do.call(rbind, lapply(split(cohort, cohort$cycle), function(x) {
  data.frame(cycle = x$cycle[1], adults = nrow(x),
             smokers = sum(x$smoker == 1), nonsmokers = sum(x$smoker == 0),
             not_examined = sum(!x$examined),
             cotinine_missing = sum(is.na(x$cotinine)),
             missing_examined = sum(is.na(x$cotinine) & x$examined),
             below_lod = sum(x$below_lod))
}))
all_rows <- data.frame(cycle = "All three", t(colSums(by_cycle[, -1])))
by_cycle <- rbind(by_cycle, all_rows)
by_cycle$missing_share <- by_cycle$cotinine_missing / by_cycle$adults

complete <- cohort[!is.na(cohort$cotinine), ]
by_race <- as.data.frame.matrix(table(complete$race, complete$smoker))
names(by_race) <- c("nonsmokers", "smokers")
by_race$race <- rownames(by_race)
rownames(by_race) <- NULL
by_race$smoker_share <- by_race$smokers /
  (by_race$smokers + by_race$nonsmokers)

missing_by_status <- data.frame(
  smoker = c(0, 1),
  missing_share = c(mean(is.na(cohort$cotinine[cohort$smoker == 0])),
                    mean(is.na(cohort$cotinine[cohort$smoker == 1]))))

curve <- RealYoudenCurve(log10(complete$cotinine), complete$smoker)
curve$cutoff_ng_ml <- 10^(curve$center + curve$scale * curve$c_star)
curve$cutoff_empirical_ng_ml <- 10^(curve$center + curve$scale *
                                      curve$c_star_empirical)

# The adult cutoff of Tompkins, Beltran, and Bedno (2019), 3.63 ng/mL
# (passage in manuscript/citations.csv), and the full-data empirical index
# there, to show how flat the curve is near its maximum.
reference_cutoff <- 3.63
xs <- (log10(complete$cotinine) - curve$center) / curve$scale
emp <- EmpiricalCurves(matrix(xs), complete$smoker)
curve$reference_cutoff_ng_ml <- reference_cutoff
curve$j_at_reference <- StepValue(
  (log10(reference_cutoff) - curve$center) / curve$scale, emp$u,
  emp$values[1, ])

density_data <- data.frame(log10_cotinine = log10(complete$cotinine),
                           smoker = complete$smoker)

saveRDS(list(by_cycle = by_cycle, by_race = by_race,
             missing_by_status = missing_by_status, curve = curve,
             density_data = density_data, n_complete = nrow(complete),
             lod = 0.015),
        here::here("pilot", "results", "nhanes_summary.rds"))
saveRDS(list(run = "pilot", n_rep = NA_integer_, n_cells = NA_integer_,
             date = Sys.time(),
             note = "NHANES 2013-2018 adult cotinine cohort, described",
             n_rep_production = NA_integer_,
             session = utils::sessionInfo()),
        here::here("pilot", "results", "nhanes_run_info.rds"))
print(by_cycle, row.names = FALSE)
print(by_race, row.names = FALSE)
cat("kernel cutoff", round(curve$cutoff_ng_ml, 2), "ng/mL; J*",
    round(curve$j_star, 3), "; kappa (standardized)", round(curve$kappa, 3),
    "\n")
