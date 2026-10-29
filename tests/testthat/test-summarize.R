# Tests for R/summarize.R: Monte Carlo standard errors and the per-cell
# summaries.

test_that("McseMean is sd / sqrt(R)", {
  x <- c(1, 4, 2, 8, 5)
  expect_equal(McseMean(x), sd(x) / sqrt(5))
  expect_equal(McseMean(c(3, 3, 3)), 0)
  # Matches the standard error of a mean from a linear model.
  set.seed(1)
  y <- rnorm(40)
  expect_equal(McseMean(y),
               summary(lm(y ~ 1))$coefficients[1, "Std. Error"])
})

test_that("RatioOfMeans returns mean(a) / mean(b) and a delta-method MCSE", {
  set.seed(2)
  b <- rnorm(200, 4, 1)
  a <- 0.5 * b + rnorm(200, 0, 0.5)
  out <- RatioOfMeans(a, b)
  expect_named(out, c("ratio", "mcse"))
  expect_equal(out[["ratio"]], mean(a) / mean(b))
  r <- mean(a) / mean(b)
  # Delta method: variance of the residual a - r * b over R * mean(b)^2.
  v <- var(a - r * b) / (200 * mean(b)^2)
  expect_equal(out[["mcse"]], sqrt(v), tolerance = 1e-10)
  expect_gt(out[["mcse"]], 0)
})

test_that("RatioOfMeans' MCSE tracks the spread of the ratio across samples", {
  set.seed(3)
  n <- 100
  ratios <- numeric(1500)
  mcses <- numeric(1500)
  for (i in seq_along(ratios)) {
    b <- rnorm(n, 4, 1)
    a <- 0.5 * b + rnorm(n, 0, 0.7)
    out <- RatioOfMeans(a, b)
    ratios[i] <- out[["ratio"]]
    mcses[i] <- out[["mcse"]]
  }
  expect_equal(mean(mcses), sd(ratios), tolerance = 0.1)
})

test_that("RatioOfMeans has zero MCSE when there is no variation", {
  out <- RatioOfMeans(rep(2, 10), rep(4, 10))
  expect_equal(out[["ratio"]], 0.5)
  expect_equal(out[["mcse"]], 0)
  # An exactly proportional pair also has no uncertainty in the ratio.
  b <- c(1, 2, 3, 4, 5)
  out2 <- RatioOfMeans(3 * b, b)
  expect_equal(out2[["ratio"]], 3)
  expect_lt(out2[["mcse"]], 1e-12)
})

test_that("RmseMcse matches the delta method for sqrt(mean(err^2))", {
  err <- c(0.3, -0.1, 0.25, -0.4, 0.05, 0.2)
  out <- RmseMcse(err)
  expect_named(out, c("rmse", "mcse"))
  expect_equal(out[["rmse"]], sqrt(mean(err^2)))
  expect_equal(out[["mcse"]],
               sd(err^2) / sqrt(6) / (2 * sqrt(mean(err^2))))
  expect_equal(RmseMcse(rep(-2, 8)), c(rmse = 2, mcse = 0))
})

test_that("RmseMcse's MCSE is about the spread of RMSE across samples", {
  set.seed(4)
  res <- vapply(1:1500, function(i) RmseMcse(rnorm(100, 0, 2)), numeric(2))
  expect_equal(mean(res["mcse", ]), sd(res["rmse", ]), tolerance = 0.1)
})

test_that("CorMcse returns r and (1 - r^2) / sqrt(R - 3)", {
  set.seed(5)
  x <- rnorm(50)
  y <- 0.6 * x + rnorm(50)
  out <- CorMcse(x, y)
  expect_named(out, c("r", "mcse"))
  expect_equal(out[["r"]], cor(x, y))
  expect_equal(out[["mcse"]], (1 - cor(x, y)^2) / sqrt(47))
  perfect <- CorMcse(1:10, 2 * (1:10))
  expect_equal(perfect[["r"]], 1)
  expect_equal(perfect[["mcse"]], 0, tolerance = 1e-12)
})

test_that("CorMcse is NA when either variable has no spread", {
  out <- CorMcse(rep(1, 10), 1:10)
  expect_true(is.na(out[["r"]]))
  expect_true(is.na(out[["mcse"]]))
  expect_named(out, c("r", "mcse"))
  out2 <- CorMcse(1:10, rep(0, 10))
  expect_true(all(is.na(out2)))
})

# Fake per-replicate rows with the columns SummarizeCell() reads.
FakeReps <- function(n_rep = 40, seed = 1, truth = MarkerTruth(2, 1)) {
  set.seed(seed)
  b_c <- runif(n_rep, 0.01, 0.1)
  gap <- 0.5 * truth$kappa * b_c + rnorm(n_rep, 0, 0.002)
  j_p1 <- truth$j_star + rnorm(n_rep, -0.01, 0.01)
  data.frame(
    miss_frac = runif(n_rep, 0.35, 0.45),
    c_p1 = truth$c_star + rnorm(n_rep, 0.02, 0.2),
    c_p2 = truth$c_star + rnorm(n_rep, 0.00, 0.2),
    c_p3 = truth$c_star + rnorm(n_rep, 0.01, 0.2),
    j_p1 = j_p1, j_p2 = j_p1 + gap, j_p3 = j_p1 + gap / 2,
    tj_p1 = truth$j_star - runif(n_rep, 0, 0.02),
    tj_p2 = truth$j_star - runif(n_rep, 0, 0.02),
    tj_p3 = truth$j_star - runif(n_rep, 0, 0.02),
    gap = gap, b_c = b_c,
    pred_gap = truth$kappa * b_c / 2,
    pred_cdiff = truth$tau * b_c / (2 * truth$kappa),
    pred_gap_hat = 0.9 * truth$kappa * b_c / 2,
    cover_mid = rbinom(n_rep, 1, 0.9), cover_lo = rbinom(n_rep, 1, 0.9),
    cover_hi = rbinom(n_rep, 1, 0.9), width_mid = runif(n_rep, 0.1, 0.2))
}

test_that("SummarizeCell reports the means and MCSEs of the replicates", {
  truth <- MarkerTruth(2, 1)
  reps <- FakeReps(40, 1, truth)
  out <- SummarizeCell(reps, truth)
  expect_s3_class(out, "data.frame")
  expect_equal(nrow(out), 1L)
  expect_equal(out$n_rep, 40)
  expect_equal(out$miss_frac, mean(reps$miss_frac))
  for (rule in c("p1", "p2", "p3")) {
    err_c <- reps[[paste0("c_", rule)]] - truth$c_star
    err_j <- reps[[paste0("j_", rule)]] - truth$j_star
    regret <- truth$j_star - reps[[paste0("tj_", rule)]]
    expect_equal(out[[paste0("bias_c_", rule)]], mean(err_c))
    expect_equal(out[[paste0("bias_c_", rule, "_mcse")]],
                 sd(err_c) / sqrt(40))
    expect_equal(out[[paste0("rmse_c_", rule)]], sqrt(mean(err_c^2)))
    expect_equal(out[[paste0("rmse_c_", rule, "_mcse")]],
                 RmseMcse(err_c)[["mcse"]])
    expect_equal(out[[paste0("bias_j_", rule)]], mean(err_j))
    expect_equal(out[[paste0("bias_j_", rule, "_mcse")]],
                 sd(err_j) / sqrt(40))
    expect_equal(out[[paste0("regret_", rule)]], mean(regret))
    expect_equal(out[[paste0("regret_", rule, "_mcse")]],
                 sd(regret) / sqrt(40))
  }
  expect_gt(out$regret_p1, 0)
})

test_that("SummarizeCell's gap and prediction measures are right", {
  truth <- MarkerTruth(2, 1)
  reps <- FakeReps(40, 2, truth)
  out <- SummarizeCell(reps, truth)
  expect_equal(out$gap, mean(reps$gap))
  expect_equal(out$gap_mcse, sd(reps$gap) / sqrt(40))
  expect_equal(out$gap_min, min(reps$gap))
  expect_equal(out$gap_n_nonzero, sum(reps$gap != 0))
  expect_equal(out$pred_gap, mean(reps$pred_gap))
  expect_equal(out$b_c, mean(reps$b_c))
  expect_equal(out$gap_ratio, mean(reps$gap) / mean(reps$pred_gap))
  expect_equal(out$gap_ratio_hat, mean(reps$gap) / mean(reps$pred_gap_hat))
  expect_equal(out$gap_ratio_mcse,
               RatioOfMeans(reps$gap, reps$pred_gap)[["mcse"]])
  expect_equal(out$gap_ratio_hat_mcse,
               RatioOfMeans(reps$gap, reps$pred_gap_hat)[["mcse"]])
  cr <- cor(reps$b_c, reps$gap)
  expect_equal(out$cor_b_gap, cr)
  expect_equal(out$cor_b_gap_mcse, (1 - cr^2) / sqrt(37))
  expect_equal(out$cdiff, mean(reps$c_p1 - reps$c_p2))
  expect_equal(out$cdiff_mcse, sd(reps$c_p1 - reps$c_p2) / sqrt(40))
  expect_equal(out$pred_cdiff, mean(reps$pred_cdiff))
  expect_equal(out$width_mid, mean(reps$width_mid))
})

test_that("SummarizeCell's ratio measures use the delta method", {
  truth <- MarkerTruth(2, 1)
  reps <- FakeReps(60, 3, truth)
  out <- SummarizeCell(reps, truth)
  br <- RatioOfMeans(reps$j_p1 - truth$j_star, reps$j_p2 - truth$j_star)
  expect_equal(out$bias_j_ratio, br[["ratio"]])
  expect_equal(out$bias_j_ratio_mcse, br[["mcse"]])
  sq1 <- (reps$c_p1 - truth$c_star)^2
  sq2 <- (reps$c_p2 - truth$c_star)^2
  rq <- RatioOfMeans(sq2, sq1)
  expect_equal(out$rmse_ratio, sqrt(mean(sq2) / mean(sq1)))
  expect_equal(out$rmse_ratio_mcse,
               rq[["mcse"]] / (2 * sqrt(rq[["ratio"]])))
})

test_that("SummarizeCell's coverage MCSE is binomial", {
  truth <- MarkerTruth(2, 1)
  reps <- FakeReps(50, 4, truth)
  out <- SummarizeCell(reps, truth)
  for (at in c("mid", "lo", "hi")) {
    p <- mean(reps[[paste0("cover_", at)]])
    expect_equal(out[[paste0("cover_", at)]], p)
    expect_equal(out[[paste0("cover_", at, "_mcse")]],
                 sqrt(p * (1 - p) / 50))
  }
})

test_that("SummarizeCell gives NA ratios when their denominators vanish", {
  truth <- MarkerTruth(2, 1)
  reps <- FakeReps(30, 5, truth)
  # No predicted gap, no estimated curvature, and P1 exactly at the truth.
  reps$pred_gap <- 0
  reps$pred_gap_hat <- NA_real_
  reps$c_p1 <- truth$c_star
  out <- SummarizeCell(reps, truth)
  expect_true(is.na(out$gap_ratio))
  expect_true(is.na(out$gap_ratio_mcse))
  expect_true(is.na(out$gap_ratio_hat))
  expect_true(is.na(out$gap_ratio_hat_mcse))
  expect_true(is.na(out$rmse_ratio))
  expect_true(is.na(out$rmse_ratio_mcse))
})

test_that("SummarizeCell of a no-missing cell has a zero gap and NA cor", {
  truth <- MarkerTruth(2, 1)
  reps <- FakeReps(30, 6, truth)
  reps$gap <- 0
  reps$b_c <- 0
  reps$pred_gap <- 0
  out <- SummarizeCell(reps, truth)
  expect_equal(out$gap, 0)
  expect_equal(out$gap_mcse, 0)
  expect_equal(out$gap_n_nonzero, 0L)
  expect_true(is.na(out$cor_b_gap))
})

test_that("SummarizeAllCells gives one row per cell and estimator", {
  d <- PilotDesign()
  keep <- d[d$cell %in% c(3, 15), ]
  truth_sharp <- MarkerTruth(2, 1)
  truth_flat <- MarkerTruth(1.5, 2.5)
  reps <- rbind(
    cbind(FakeReps(25, 11, truth_sharp), cell = 3, estimator = "kernel"),
    cbind(FakeReps(25, 12, truth_flat), cell = 15, estimator = "empirical"),
    cbind(FakeReps(25, 13, truth_sharp), cell = 3, estimator = "empirical"),
    cbind(FakeReps(25, 14, truth_flat), cell = 15, estimator = "kernel"))
  out <- SummarizeAllCells(reps, keep)
  expect_equal(nrow(out), 4L)
  expect_equal(out$cell, c(3, 3, 15, 15))
  expect_equal(out$estimator, rep(c("empirical", "kernel"), 2))
  expect_true(all(names(keep) %in% names(out)))
  expect_equal(out$c_star, rep(c(truth_sharp$c_star, truth_flat$c_star),
                               each = 2))
  expect_equal(out$kappa, rep(c(truth_sharp$kappa, truth_flat$kappa),
                              each = 2))
  expect_equal(out$j_star, rep(c(truth_sharp$j_star, truth_flat$j_star),
                               each = 2))
  expect_equal(out$tau, rep(c(truth_sharp$tau, truth_flat$tau), each = 2))
  expect_equal(out$shape, rep(c("sharp", "flat"), each = 2))
})

test_that("SummarizeAllCells summarizes each cell with its own replicates", {
  d <- PilotDesign()
  keep <- d[d$cell %in% c(3, 15), ]
  truth_sharp <- MarkerTruth(2, 1)
  truth_flat <- MarkerTruth(1.5, 2.5)
  r1 <- cbind(FakeReps(25, 21, truth_sharp), cell = 3, estimator = "empirical")
  r2 <- cbind(FakeReps(30, 22, truth_flat), cell = 15, estimator = "empirical")
  out <- SummarizeAllCells(rbind(r1, r2), keep)
  expect_equal(nrow(out), 2L)
  expect_equal(out$n_rep, c(25, 30))
  expect_equal(out$gap, c(mean(r1$gap), mean(r2$gap)))
  expect_equal(out$bias_c_p1,
               c(mean(r1$c_p1 - truth_sharp$c_star),
                 mean(r2$c_p1 - truth_flat$c_star)))
  expect_equal(out$cover_mid, c(mean(r1$cover_mid), mean(r2$cover_mid)))
  # The same numbers as SummarizeCell() on the cell's rows.
  one <- SummarizeCell(r2, truth_flat)
  expect_equal(out$rmse_c_p2[2], one$rmse_c_p2)
})
