# Known-answer checks of the pilot code (pilot/preregistration.md,
# section 4). tests/testthat/test-known-answers.R asserts that every check
# passes; pilot/pilot.R saves the table so the report can display it.

#' One row of the known-answer table
#'
#' @param check,setting,known Labels: what is checked, on what, and the
#'   known answer in words.
#' @param truth The known value.
#' @param computed What the code gave.
#' @param tolerance Allowed absolute gap (`type = "tol"`), the Monte Carlo
#'   standard error (`type = "mcse"`, passing within three), or unused
#'   (`type = "atleast"`, passing when `computed >= truth`).
#' @param type `"tol"`, `"mcse"`, or `"atleast"`.
#' @return A one-row data frame with a logical `pass`.
#' @keywords internal
KnownRow <- function(check, setting, known, truth, computed, tolerance,
                     type) {
  gap <- abs(computed - truth)
  pass <- switch(type, tol = gap <= tolerance, mcse = gap <= 3 * tolerance,
                 atleast = computed >= truth)
  data.frame(check = check, setting = setting, known = known, truth = truth,
             computed = computed, tolerance = tolerance, type = type,
             pass = pass, stringsAsFactors = FALSE)
}

#' Run the known-answer checks
#'
#' Each check runs package code on a case whose answer is known: closed
#' forms of the binormal model, the quadratic and cubic gap formulas on
#' synthetic curves, the Jensen inequality on random curves, the expectation
#' of the kernel distribution function, the stacking lemma, the
#' nearest-neighbour donors against a literal search, the missingness
#' intercept, and pooling identical curves.
#'
#' @param seed Seed for the random parts.
#' @return A data frame, one row per check (see `KnownRow()`).
#' @export
KnownAnswerChecks <- function(seed = 20261028L) {
  set.seed(seed)
  rows <- list()

  sharp <- MarkerTruth(2, 1)
  rows[[1]] <- KnownRow("Optimal cutoff", "sharp shape", "c* = 1", 1,
                        sharp$c_star, 1e-6, "tol")
  rows[[2]] <- KnownRow("Maximum of J", "sharp shape", "J* = 2 Phi(1) - 1",
                        2 * stats::pnorm(1) - 1, sharp$j_star, 1e-10, "tol")
  rows[[3]] <- KnownRow("Curvature at c*", "sharp shape",
                        "kappa = 2 phi(1)", 2 * stats::dnorm(1),
                        sharp$kappa, 1e-6, "tol")

  # Quadratic curves with unequal curvatures: the pooled maximizer is the
  # curvature-weighted mean and the gap is the closed form, exactly.
  n_curves <- 7
  kappa_l <- stats::runif(n_curves, 0.2, 1)
  c_l <- stats::rnorm(n_curves, 1, 0.1)
  m_l <- stats::runif(n_curves, 0.5, 0.7)
  quad <- function(cc, l) m_l[l] - kappa_l[l] / 2 * (cc - c_l[l])^2
  pooled <- PoolSmoothCurves(quad, n_curves, seq(0, 2, length.out = 201),
                             tol = 1e-12)
  c_tilde <- sum(kappa_l * c_l) / sum(kappa_l)
  gap_formula <- mean(kappa_l / 2 * (c_l - c_tilde)^2)
  rows[[4]] <- KnownRow("Pool-first cutoff", "7 quadratic curves",
                        "curvature-weighted mean of the cutoffs", c_tilde,
                        pooled$cutoff[["p1"]], 1e-10, "tol")
  rows[[5]] <- KnownRow("Gap", "7 quadratic curves",
                        "mean of kappa_l (c_l - c_tilde)^2 / 2", gap_formula,
                        pooled$index[["p2"]] - pooled$index[["p1"]], 1e-10,
                        "tol")

  # Cubic curves with common kappa and tau: the cutoff difference matches
  # tau B / (2 kappa) to first order in the spread.
  cubic_ratio <- function(spread) {
    cc_l <- 1 + spread * stats::qnorm(stats::ppoints(n_curves))
    cub <- function(cc, l) {
      0.6 - 0.5 / 2 * (cc - cc_l[l])^2 + 0.2 / 6 * (cc - cc_l[l])^3
    }
    p <- PoolSmoothCurves(cub, n_curves, seq(0.5, 1.5, length.out = 201),
                          tol = 1e-12)
    (p$cutoff[["p1"]] - p$cutoff[["p2"]]) / (0.2 * p$b_c / (2 * 0.5))
  }
  rows[[6]] <- KnownRow("Cutoff difference", "7 cubic curves, spread 0.01",
                        "ratio to tau B / (2 kappa) is 1", 1,
                        cubic_ratio(0.01), 0.01, "tol")

  # Jensen: the gap is never negative, on 1,000 sets of random step curves.
  min_gap <- min(vapply(seq_len(1000), function(i) {
    u <- sort(stats::runif(30))
    p <- PoolStepCurves(u, matrix(stats::runif(5 * 30), nrow = 5))
    p$index[["p2"]] - p$index[["p1"]]
  }, numeric(1)))
  rows[[7]] <- KnownRow("Gap never negative", "1,000 sets of 5 random curves",
                        "smallest gap >= 0", 0, min_gap, 0, "atleast")

  # Pooling identical curves: every rule agrees and the gap is exactly 0.
  dat <- SimulateMarkerData(250, 2, 1)
  copies <- matrix(dat$x_full, nrow = nrow(dat), ncol = 20)
  emp <- EmpiricalCurves(copies, dat$d)
  pe <- PoolStepCurves(emp$u, emp$values)
  kc <- KernelCurves(copies, dat$d)
  grid <- seq(-2, 4, length.out = 201)
  pk <- PoolSmoothCurves(kc$curve_fun, 20, grid, kc$grid_fun(grid))
  rows[[8]] <- KnownRow("Gap with nothing missing", "20 copies, empirical",
                        "exactly 0", 0,
                        pe$index[["p2"]] - pe$index[["p1"]], 0, "tol")
  rows[[9]] <- KnownRow("Gap with nothing missing", "20 copies, kernel",
                        "exactly 0", 0,
                        pk$index[["p2"]] - pk$index[["p1"]], 0, "tol")

  # Kernel distribution function with a fixed bandwidth on N(0, 1) data:
  # its expectation is Phi(c / sqrt(1 + h^2)).
  h <- 0.3
  draws <- vapply(seq_len(2000), function(i) {
    KernelCdf(0.5, stats::rnorm(200), h)
  }, numeric(1))
  rows[[10]] <- KnownRow("Kernel distribution function",
                         "fixed h = 0.3, 2,000 samples of 200, c = 0.5",
                         "Phi(c / sqrt(1 + h^2))",
                         stats::pnorm(0.5 / sqrt(1 + h^2)), mean(draws),
                         McseMean(draws), "mcse")

  # Stacking lemma: the stacked empirical curve equals the averaged curve.
  dat2 <- SimulateMarkerData(100, 2, 1, MissingIntercept(0.4, 2, 1))
  completed <- ImputePmm(dat2$x, dat2$d, dat2$z, 10)
  per <- EmpiricalCurves(completed, dat2$d)
  stacked <- EmpiricalCurves(matrix(as.vector(completed)),
                             rep(dat2$d, 10))
  rows[[11]] <- KnownRow("Stacking lemma", "10 imputations, empirical",
                         "stacked curve equals averaged curve", 0,
                         max(abs(stacked$values[1, ] - PoolMean(per$values))),
                         1e-12, "tol")

  # Nearest-neighbour donors with one auxiliary: the k nearest observed
  # subjects in Z within the same group, by a literal search.
  dat3 <- SimulateMarkerData(60, 2, 1, MissingIntercept(0.4, 2, 1))
  w_mat <- cbind(1, dat3$d, dat3$z, dat3$d * dat3$z)
  s1 <- as.vector(scale(w_mat %*% c(0, 0.5, 0.6, 0.2)))
  s2 <- as.vector(scale(w_mat %*% c(-1, 0.4, 1.1, -0.3)))
  donors <- NearestDonors(s1, s2, dat3$observed, dat3$d, k = 3)
  missing_idx <- which(!dat3$observed)
  literal <- vapply(missing_idx, function(i) {
    pool <- which(dat3$observed & dat3$d == dat3$d[i])
    sort(pool[order(abs(dat3$z[pool] - dat3$z[i]))[1:3]])
  }, integer(3))
  rows[[12]] <- KnownRow("Nearest-neighbour donors",
                         "one auxiliary, k = 3",
                         "subjects not matching a literal search in Z", 0,
                         sum(apply(donors, 2, sort) != literal), 0, "tol")

  # Missingness intercept: the simulated fraction matches the target.
  alpha0 <- MissingIntercept(0.4, 1.5, 2.5)
  big <- SimulateMarkerData(1e5, 1.5, 2.5, alpha0)
  p_miss <- mean(!big$observed)
  rows[[13]] <- KnownRow("Missing fraction", "flat shape, 200,000 subjects",
                         "target 0.40", 0.4, p_miss,
                         sqrt(0.4 * 0.6 / nrow(big)), "mcse")
  do.call(rbind, rows)
}
