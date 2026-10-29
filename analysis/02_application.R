# The application (protocol.md): serum cotinine and current smoking among
# NHANES adults, 2013 to 2018, on the log10 scale of ng/mL. Three analyses
# of the whole cohort (the real missing values imputed; the complete cases
# without imputation, the benchmark; the complete cases with 40% missing
# imposed at random) and one per race/ethnicity stratum, each with the
# procedure of the simulation study (MiYoudenInference()).
#
# Run from the project root after analysis/00_download.R:
#   Rscript analysis/02_application.R [workers]
# Writes results/application.rds and results/application_run_info.rds.

devtools::load_all(quiet = TRUE)

# ---- parameters ---------------------------------------------------------
settings <- list(n_imp = 20L, n_boot = 1000L, m_boot = 2L,
                 n_boot_opt = 100L, n_boot_opt2 = 200L, grid_n = 41L,
                 n_draw = 5000L)
imposed_rate <- 0.4
reference_ng_ml <- 3.63   # Tompkins, Beltran, and Bedno (2019), adults
base_seed <- 20261102L
n_workers <- 3L

# ---- data ---------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
if (length(args)) n_workers <- as.integer(args[1])
set.seed(base_seed)
cohort <- ReadApplicationCohort(here::here("data", "raw"))
cohort <- cohort[order(cohort$cycle, cohort$seqn), ]
cohort$x <- log10(cohort$cotinine)
complete <- cohort[!is.na(cohort$x), ]

by_cycle <- do.call(rbind, lapply(split(cohort, cohort$cycle), function(c) {
  data.frame(cycle = c$cycle[1], adults = nrow(c),
             smokers = sum(c$smoker == 1), nonsmokers = sum(c$smoker == 0),
             cotinine_missing = sum(is.na(c$x)),
             not_examined = sum(!c$examined),
             below_lod = sum(c$below_lod, na.rm = TRUE))
}))
missing_by_status <- tapply(is.na(cohort$x), cohort$smoker, mean)
placement <- RealYoudenCurve(complete$x, complete$smoker)
placement$reference_ng_ml <- reference_ng_ml
xs_ref <- (log10(reference_ng_ml) - placement$center) / placement$scale
emp_full <- EmpiricalCurves(matrix((complete$x - placement$center) /
                                     placement$scale), complete$smoker)
placement$j_at_reference <- StepValue(xs_ref, emp_full$u,
                                      emp_full$values[1, ])

# ---- tasks --------------------------------------------------------------
Task <- function(name, k, x, d, predictors) {
  c(list(name = name, seed = base_seed + 1000L * k, x = x, d = d,
         predictors = predictors), settings)
}
imposed <- ImposeMissing(complete, imposed_rate)
x_imposed <- ifelse(imposed, NA_real_, complete$x)
tasks <- list(
  Task("real", 1L, cohort$x, cohort$smoker, CotininePredictors(cohort)),
  Task("full", 2L, complete$x, complete$smoker,
       CotininePredictors(complete)),
  Task("imposed", 3L, x_imposed, complete$smoker,
       CotininePredictors(complete)))
races <- sort(unique(cohort$race))
for (i in seq_along(races)) {
  s <- cohort[cohort$race == races[i], ]
  tasks[[length(tasks) + 1]] <- Task(
    paste0("race: ", races[i]), 10L + i, s$x, s$smoker,
    CotininePredictors(s, drop = "race"))
}

start <- Sys.time()
res <- RunApplicationTasks(tasks, n_workers)
runtime_minutes <- as.numeric(difftime(Sys.time(), start, units = "mins"))

# ---- summaries ----------------------------------------------------------
ref <- log10(reference_ng_ml)
real <- SummarizeAnalysis(res$real, ref)
full <- SummarizeAnalysis(res$full, ref)
imp <- SummarizeAnalysis(res$imposed, ref)

# The benchmark: the complete cases' own curve on the imposed analysis's
# grid and at its chosen cutoff.
full_on_grid <- PoolMean(GridCurves(matrix(complete$x), complete$smoker,
                                    imp$grid)$j)
emp_c <- EmpiricalCurves(matrix(complete$x), complete$smoker)
k_full <- which.max(full_on_grid)
imp$benchmark <- list(
  curve = full_on_grid, k_best = k_full,
  band_covers = c(
    boot = BandCovers(imp$boot$lower, imp$boot$upper, full_on_grid),
    hybrid = BandCovers(imp$hybrid$lower, imp$hybrid$upper, full_on_grid),
    rubin = BandCovers(imp$rubin$lower, imp$rubin$upper, full_on_grid),
    pointwise = BandCovers(imp$pointwise$lower, imp$pointwise$upper,
                           full_on_grid)),
  set_contains = vapply(imp$sets, function(s) s[k_full], logical(1)),
  full_at_c_hat = StepValue(imp$c_hat, emp_c$u, emp_c$values[1, ]),
  full_max = MaximizeStep(emp_c$u, emp_c$values[1, ]))

w <- table(factor(cohort$race, levels = races), cohort$smoker)
strata <- do.call(rbind, lapply(seq_along(races), function(i) {
  r <- res[[paste0("race: ", races[i])]]
  s <- cohort[cohort$race == races[i], ]
  cut <- StratumCutoffs(r$completed, s$smoker,
                        w0 = w[i, "0"] / sum(w[, "0"]),
                        w1 = w[i, "1"] / sum(w[, "1"]))
  rng <- range(r$grid[r$hybrid$comp_set])
  data.frame(race = races[i], smokers = sum(s$smoker == 1),
             nonsmokers = sum(s$smoker == 0),
             missing_share = mean(is.na(s$x)),
             c_cs = cut$c_cs, j_cs = cut$j_cs, c_pop = cut$c_pop,
             corrected_20 = r$corrected_20, apparent = r$apparent,
             set_lo = rng[1], set_hi = rng[2],
             reference_in_set = r$hybrid$comp_set[
               which.min(abs(r$grid - ref))],
             stringsAsFactors = FALSE)
}))

saveRDS(list(by_cycle = by_cycle, missing_by_status = missing_by_status,
             n_adults = nrow(cohort), n_complete = nrow(complete),
             placement = placement, real = real, full = full,
             imposed = imp, imposed_share = mean(imposed), strata = strata,
             settings = settings, imposed_rate = imposed_rate,
             task_seconds = vapply(res, function(r) r$seconds, numeric(1))),
        here::here("results", "application.rds"))
saveRDS(list(run = "production", n_rep = NA_integer_, n_cells = NA_integer_,
             date = Sys.time(),
             note = paste("Application, analysis/02_application.R; the",
                          "protocol's settings, nothing reduced"),
             n_rep_production = NA_integer_,
             runtime_minutes = runtime_minutes, n_workers = n_workers,
             session = utils::sessionInfo()),
        here::here("results", "application_run_info.rds"))
cat("application finished in", round(runtime_minutes, 1), "minutes\n")
