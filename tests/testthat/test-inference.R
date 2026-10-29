# Tests for R/inference.R: the pooled Youden curve on a grid, the Rubin's-rules
# and bootstrap-then-impute sup-t bands, the near-optimal set, the bootstrap
# optimism, the resampler, and the two imputation engines added for the
# re-pilot (pilot-b/preregistration.md, section 2).

# Completed data for two groups: an N x L matrix whose group-1 rows are
# shifted by one, and the disease status.
SimCompleted <- function(n0, n1, n_imp, seed) {
  set.seed(seed)
  d <- rep(0:1, c(n0, n1))
  x <- matrix(rnorm((n0 + n1) * n_imp), n0 + n1, n_imp)
  x[d == 1, ] <- x[d == 1, ] + 1
  list(x = x, d = d)
}

# The covariance of the Youden curve as a literal double loop.
LiteralCov <- function(f0, f1, n0, n1) {
  k <- length(f0)
  out <- matrix(0, k, k)
  for (i in seq_len(k)) {
    for (j in seq_len(k)) {
      a <- min(i, j)
      out[i, j] <- (f0[a] - f0[i] * f0[j]) / n0 +
        (f1[a] - f1[i] * f1[j]) / n1
    }
  }
  out
}

# Marker data with a known conditional mean, and a copy with 40 values
# missing.
MissingData <- function(n = 120, seed = 1) {
  set.seed(seed)
  d <- rep(0:1, each = n / 2)
  z <- rnorm(n)
  x <- 1 + 0.8 * d + 0.9 * z + rnorm(n, 0, 0.3)
  x_obs <- x
  x_obs[sample(n, 40)] <- NA
  list(x = x, x_obs = x_obs, d = d, z = z)
}

# -- GridCurves ---------------------------------------------------------

test_that("GridCurves equals the literal group CDFs, column by column", {
  sim <- SimCompleted(30, 25, 3, 1)
  # Grid points that coincide with data values, to check the <= convention.
  grid <- c(-1, sim$x[3, 1], 0.2, sim$x[40, 2], 1.5)
  grid <- sort(grid)
  out <- GridCurves(sim$x, sim$d, grid)
  expect_named(out, c("f0", "f1", "j"))
  for (m in c("f0", "f1", "j")) expect_equal(dim(out[[m]]), c(3L, 5L))
  for (l in 1:3) {
    for (k in seq_along(grid)) {
      f0 <- mean(sim$x[sim$d == 0, l] <= grid[k])
      f1 <- mean(sim$x[sim$d == 1, l] <= grid[k])
      expect_equal(out$f0[l, k], f0)
      expect_equal(out$f1[l, k], f1)
      expect_equal(out$j[l, k], f0 - f1)
    }
  }
})

test_that("GridCurves keeps an L x K shape for L = 1 and K = 1", {
  sim <- SimCompleted(20, 15, 3, 2)
  grid <- c(-0.5, 0.5, 1.5)
  one_imp <- GridCurves(sim$x[, 1, drop = FALSE], sim$d, grid)
  expect_equal(dim(one_imp$j), c(1L, 3L))
  expect_equal(one_imp$f0[1, ], vapply(
    grid, function(g) mean(sim$x[sim$d == 0, 1] <= g), numeric(1)))
  one_pt <- GridCurves(sim$x, sim$d, 0.5)
  expect_equal(dim(one_pt$j), c(3L, 1L))
  expect_equal(one_pt$j[, 1], vapply(1:3, function(l) {
    mean(sim$x[sim$d == 0, l] <= 0.5) - mean(sim$x[sim$d == 1, l] <= 0.5)
  }, numeric(1)))
  both <- GridCurves(sim$x[, 1], sim$d, 0.5)
  expect_equal(dim(both$j), c(1L, 1L))
})

test_that("GridCurves is 0 below and 1 above the data", {
  sim <- SimCompleted(20, 15, 2, 3)
  out <- GridCurves(sim$x, sim$d, c(-100, 100))
  expect_equal(out$f0, matrix(c(0, 1), 2, 2, byrow = TRUE))
  expect_equal(out$f1, matrix(c(0, 1), 2, 2, byrow = TRUE))
  expect_equal(out$j, matrix(0, 2, 2))
})

# -- YoudenCurveCov -----------------------------------------------------

test_that("YoudenCurveCov matches the literal double loop", {
  f0 <- c(0.1, 0.3, 0.6, 0.9)
  f1 <- c(0.05, 0.1, 0.4, 0.8)
  expect_equal(YoudenCurveCov(f0, f1, 50, 30), LiteralCov(f0, f1, 50, 30))
})

test_that("YoudenCurveCov is symmetric with the binomial diagonal", {
  f0 <- c(0.02, 0.2, 0.5, 0.7, 0.95)
  f1 <- c(0.01, 0.05, 0.3, 0.6, 0.9)
  out <- YoudenCurveCov(f0, f1, 40, 60)
  expect_equal(dim(out), c(5L, 5L))
  expect_equal(out, t(out))
  expect_equal(diag(out), f0 * (1 - f0) / 40 + f1 * (1 - f1) / 60)
  expect_gte(min(eigen(out, symmetric = TRUE)$values), -1e-12)
})

test_that("YoudenCurveCov handles one point and saturated points", {
  expect_equal(YoudenCurveCov(0.4, 0.1, 10, 20),
               matrix(0.4 * 0.6 / 10 + 0.1 * 0.9 / 20, 1, 1))
  # Where both distribution functions reach 1 there is no variance and no
  # covariance with any other point.
  out <- YoudenCurveCov(c(0.3, 1), c(0.2, 1), 25, 25)
  expect_equal(out[2, ], c(0, 0))
  expect_equal(out[, 2], c(0, 0))
})

# -- SupTCritical -------------------------------------------------------

test_that("SupTCritical for one coordinate is the normal quantile", {
  set.seed(1)
  expect_equal(SupTCritical(matrix(4, 1, 1), 0.95, 2e5), qnorm(0.975),
               tolerance = 0.02)
  set.seed(1)
  expect_equal(SupTCritical(matrix(0.01, 1, 1), 0.9, 2e5), qnorm(0.95),
               tolerance = 0.02)
  set.seed(2)
  q <- SupTCritical(matrix(1, 1, 1), 0.95, 1000)
  expect_type(q, "double")
  expect_length(q, 1L)
  expect_null(names(q))
})

test_that("SupTCritical with identical coordinates is the one-point value", {
  set.seed(3)
  expect_equal(SupTCritical(matrix(1, 6, 6), 0.95, 2e5), qnorm(0.975),
               tolerance = 0.02)
  # Perfectly correlated coordinates on different scales: rank one too.
  s <- c(1, 2, 3.5)
  set.seed(3)
  expect_equal(SupTCritical(outer(s, s), 0.95, 2e5), qnorm(0.975),
               tolerance = 0.02)
})

test_that("SupTCritical for independent coordinates matches the formula", {
  for (k in c(5, 41)) {
    set.seed(4)
    expected <- qnorm((1 + 0.95^(1 / k)) / 2)
    expect_equal(SupTCritical(diag(k), 0.95, 5e4), expected,
                 tolerance = 0.02)
  }
})

test_that("SupTCritical grows with K and with the level", {
  set.seed(5)
  q <- vapply(c(1, 3, 10, 30), function(k) {
    SupTCritical(diag(k), 0.95, 2e4)
  }, numeric(1))
  expect_true(all(diff(q) > 0))
  # Equicorrelated coordinates sit between the rank-one and independent
  # cases.
  rho <- 0.5
  sigma <- matrix(rho, 6, 6) + diag(1 - rho, 6)
  set.seed(5)
  q_mid <- SupTCritical(sigma, 0.95, 5e4)
  expect_gt(q_mid, qnorm(0.975) + 0.1)
  expect_lt(q_mid, qnorm((1 + 0.95^(1 / 6)) / 2))
  lev <- vapply(c(0.5, 0.9, 0.99), function(l) {
    set.seed(6)
    SupTCritical(diag(4), l, 2e4)
  }, numeric(1))
  expect_true(all(diff(lev) > 0))
})

test_that("SupTCritical leaves out zero-variance coordinates", {
  set.seed(7)
  with_zero <- SupTCritical(diag(c(1, 0, 1)), 0.95, 5000)
  set.seed(7)
  without <- SupTCritical(diag(2), 0.95, 5000)
  expect_equal(with_zero, without)
  # Nothing left: the one-point value, without any draws.
  expect_equal(SupTCritical(matrix(0, 3, 3)), qnorm(0.975))
  expect_equal(SupTCritical(matrix(0, 2, 2), level = 0.9), qnorm(0.95))
})

test_that("SupTCritical tolerates a slightly indefinite covariance", {
  sigma <- matrix(c(1, 1.2, 1.2, 1), 2)
  expect_lt(min(eigen(sigma)$values), 0)
  set.seed(8)
  q <- SupTCritical(sigma, 0.95, 5000)
  expect_true(is.finite(q))
  expect_gt(q, 1.5)
})

test_that("SupTCritical is reproducible given the seed", {
  set.seed(9)
  a <- SupTCritical(diag(4), 0.95, 3000)
  set.seed(9)
  b <- SupTCritical(diag(4), 0.95, 3000)
  expect_identical(a, b)
})

# -- RubinBand and PointwiseRubinBand -----------------------------------

test_that("RubinBand of identical curves has no between part", {
  sim <- SimCompleted(40, 30, 1, 11)
  completed <- sim$x[, rep(1, 4)]
  grid <- quantile(sim$x[, 1], c(0.15, 0.3, 0.5, 0.7, 0.85))
  gc <- GridCurves(completed, sim$d, grid)
  set.seed(1)
  rb <- RubinBand(gc, 40, 30, n_draw = 4000)
  u <- LiteralCov(gc$f0[1, ], gc$f1[1, ], 40, 30)
  expect_equal(rb$estimate, gc$j[1, ])
  expect_equal(rb$se, sqrt(diag(u)))
  expect_true(all(rb$lower <= rb$estimate & rb$estimate <= rb$upper))
  expect_equal(rb$upper - rb$estimate, rb$q * rb$se)
  expect_equal(rb$estimate - rb$lower, rb$q * rb$se)
  # Five correlated points: above the one-point value, below Bonferroni.
  expect_gt(rb$q, qnorm(0.975))
  expect_lt(rb$q, qnorm(1 - 0.025 / 5) + 0.1)
})

test_that("RubinBand is Rubin's rules on the grid, with a literal T", {
  sim <- SimCompleted(40, 30, 4, 12)
  grid <- seq(-0.5, 1.5, length.out = 7)
  gc <- GridCurves(sim$x, sim$d, grid)
  set.seed(2)
  rb <- RubinBand(gc, 40, 30, n_draw = 3000)
  u_bar <- Reduce(`+`, lapply(1:4, function(l) {
    LiteralCov(gc$f0[l, ], gc$f1[l, ], 40, 30)
  })) / 4
  t_cov <- u_bar + (1 + 1 / 4) * cov(gc$j)
  expect_equal(rb$estimate, colMeans(gc$j))
  expect_equal(rb$se, sqrt(diag(t_cov)))
  # The between part makes the band wider than the within part alone.
  expect_true(all(rb$se >= sqrt(diag(u_bar)) - 1e-12))
  expect_gt(sum(rb$se > sqrt(diag(u_bar)) + 1e-6), 0)
  set.seed(2)
  expect_equal(rb$q, SupTCritical(t_cov, 0.95, 3000))
  expect_equal(rb$lower, rb$estimate - rb$q * rb$se)
  expect_equal(rb$upper, rb$estimate + rb$q * rb$se)
})

test_that("RubinBand works with one imputation and widens with the level", {
  sim <- SimCompleted(30, 30, 1, 13)
  grid <- seq(-0.5, 1.5, length.out = 5)
  gc <- GridCurves(sim$x, sim$d, grid)
  set.seed(3)
  rb <- RubinBand(gc, 30, 30, n_draw = 2000)
  expect_equal(rb$se, sqrt(diag(LiteralCov(gc$f0[1, ], gc$f1[1, ], 30, 30))))
  expect_equal(rb$estimate, gc$j[1, ])
  set.seed(3)
  rb99 <- RubinBand(gc, 30, 30, level = 0.99, n_draw = 2000)
  expect_gt(rb99$q, rb$q)
  expect_true(all(rb99$upper - rb99$lower > rb$upper - rb$lower))
})

test_that("PointwiseRubinBand is Rubin's interval at each grid point", {
  sim <- SimCompleted(35, 25, 5, 14)
  grid <- seq(-0.5, 1.5, length.out = 6)
  gc <- GridCurves(sim$x, sim$d, grid)
  pw <- PointwiseRubinBand(gc, 35, 25)
  expect_named(pw, c("lower", "upper"))
  expect_length(pw$lower, 6L)
  for (k in seq_along(grid)) {
    j <- gc$j[, k]
    u_bar <- mean(gc$f0[, k] * (1 - gc$f0[, k]) / 35 +
                    gc$f1[, k] * (1 - gc$f1[, k]) / 25)
    b <- var(j)
    t_var <- u_bar + (1 + 1 / 5) * b
    df <- (5 - 1) * (1 + u_bar / ((1 + 1 / 5) * b))^2
    half <- qt(0.975, df) * sqrt(t_var)
    expect_equal(pw$lower[k], mean(j) - half)
    expect_equal(pw$upper[k], mean(j) + half)
    ri <- RubinInterval(j, gc$f0[, k] * (1 - gc$f0[, k]) / 35 +
                          gc$f1[, k] * (1 - gc$f1[, k]) / 25)
    expect_equal(c(pw$lower[k], pw$upper[k]), c(ri$lower, ri$upper))
  }
  narrow <- PointwiseRubinBand(gc, 35, 25, level = 0.8)
  expect_true(all(narrow$upper - narrow$lower < pw$upper - pw$lower))
})

test_that("PointwiseRubinBand of identical curves is a normal interval", {
  sim <- SimCompleted(40, 30, 1, 15)
  completed <- sim$x[, rep(1, 3)]
  grid <- quantile(sim$x[, 1], c(0.2, 0.5, 0.8))
  gc <- GridCurves(completed, sim$d, grid)
  pw <- PointwiseRubinBand(gc, 40, 30)
  half <- qnorm(0.975) * sqrt(gc$f0[1, ] * (1 - gc$f0[1, ]) / 40 +
                                gc$f1[1, ] * (1 - gc$f1[1, ]) / 30)
  expect_equal(pw$lower, gc$j[1, ] - half)
  expect_equal(pw$upper, gc$j[1, ] + half)
  # The simultaneous band is wider than the pointwise one.
  set.seed(1)
  rb <- RubinBand(gc, 40, 30, n_draw = 3000)
  expect_true(all(rb$upper - rb$lower > pw$upper - pw$lower))
})

# -- BootImputeBand -----------------------------------------------------

test_that("BootImputeBand with identical imputations is the resample SD", {
  set.seed(21)
  a <- matrix(rnorm(400 * 6), 400, 6)
  est <- seq(0.1, 0.6, length.out = 6)
  bb <- BootImputeBand(list(a, a), est, n_imp = 20)
  expect_equal(bb$s_within, rep(0, 6))
  expect_equal(bb$v_boot, apply(a, 2, var))
  expect_equal(bb$se^2, apply(a, 2, var))
  # The critical value is a literal quantile of the studentized maxima.
  dev <- abs(sweep(a, 2, colMeans(a))) / rep(sqrt(apply(a, 2, var)),
                                              each = 400)
  expect_equal(bb$q, unname(quantile(apply(dev, 1, max), 0.95, type = 7)))
  # Limits are symmetric around the estimate.
  expect_equal(bb$upper - est, bb$q * bb$se)
  expect_equal(est - bb$lower, bb$q * bb$se)
  expect_equal((bb$upper + bb$lower) / 2, est)
})

test_that("BootImputeBand's q is near 1.96 for one point, large for many", {
  set.seed(22)
  one <- BootImputeBand(list(matrix(rnorm(2e4), ncol = 1)), 0, n_imp = 10)
  expect_equal(one$q, qnorm(0.975), tolerance = 0.05)
  many <- BootImputeBand(list(matrix(rnorm(2000 * 40), 2000, 40)),
                         rep(0, 40), n_imp = 10)
  expect_gt(many$q, 2.8)
  expect_lt(many$q, 3.8)
})

test_that("BootImputeBand splits the variance into its two parts", {
  set.seed(23)
  r_b <- 20000
  k <- 3
  a <- matrix(rnorm(r_b * k, 0, 1), r_b, k)
  boot <- lapply(1:2, function(i) a + matrix(rnorm(r_b * k, 0, 0.5), r_b, k))
  bb <- BootImputeBand(boot, rep(0, k), n_imp = 20)
  # Imputation part: s_w^2 = 0.25; V_b carries s_w^2 / M = 0.125 of it.
  expect_equal(bb$s_within, rep(0.25, k), tolerance = 0.05)
  expect_equal(bb$v_boot, rep(1.125, k), tolerance = 0.05)
  # Variance of a 20-imputation estimate: 1 + 0.25 / 20.
  expect_equal(bb$se^2, rep(1.0125, k), tolerance = 0.05)
  # The formula, exactly.
  expect_equal(bb$se^2,
               pmax(bb$v_boot - bb$s_within / 2 + bb$s_within / 20, 0))
  # With L = M imputations the variance is V_b itself.
  same <- BootImputeBand(boot, rep(0, k), n_imp = 2)
  expect_equal(same$se^2, same$v_boot)
  # With very many imputations the imputation part drops out.
  many <- BootImputeBand(boot, rep(0, k), n_imp = 1e9)
  expect_equal(many$se^2, many$v_boot - many$s_within / 2)
})

test_that("BootImputeBand with one imputation per resample has no split", {
  set.seed(24)
  a <- matrix(rnorm(300 * 4), 300, 4)
  bb <- BootImputeBand(list(a), rep(0, 4), n_imp = 5)
  expect_equal(bb$s_within, rep(0, 4))
  expect_equal(bb$se, sqrt(apply(a, 2, var)))
})

test_that("BootImputeBand with no between-resample variance collapses", {
  set.seed(25)
  e <- matrix(rnorm(200 * 3), 200, 3)
  # Two imputations that cancel: every resample's mean is exactly 0.
  boot <- list(e, -e)
  bb <- BootImputeBand(boot, c(0.2, 0.4, 0.6), n_imp = 20)
  expect_equal(bb$v_boot, rep(0, 3))
  expect_equal(bb$s_within, 2 * colMeans(e^2))
  # V_b - s_w / 2 + s_w / 20 is negative, so it is floored at zero.
  expect_equal(bb$se, rep(0, 3))
  expect_equal(bb$q, qnorm(0.975))
  expect_equal(bb$lower, c(0.2, 0.4, 0.6))
  expect_equal(bb$upper, c(0.2, 0.4, 0.6))
  # With one imputation the imputation part is all that is left.
  one <- BootImputeBand(boot, c(0.2, 0.4, 0.6), n_imp = 1)
  expect_equal(one$se^2, one$s_within / 2)
})

test_that("BootImputeBand leaves a constant grid point out of q", {
  set.seed(26)
  a <- matrix(rnorm(500 * 3), 500, 3)
  a[, 2] <- 0.5
  bb <- BootImputeBand(list(a, a), rep(0, 3), n_imp = 10)
  expect_equal(bb$v_boot[2], 0)
  expect_equal(bb$se[2], 0)
  keep <- a[, c(1, 3)]
  dev <- abs(sweep(keep, 2, colMeans(keep))) /
    rep(sqrt(apply(keep, 2, var)), each = 500)
  expect_equal(bb$q, unname(quantile(apply(dev, 1, max), 0.95, type = 7)))
})

# -- BandCovers and NearOptimalSet --------------------------------------

test_that("BandCovers is TRUE only if every grid point is covered", {
  truth <- c(0.1, 0.4, 0.6, 0.3)
  expect_true(BandCovers(truth - 0.05, truth + 0.05, truth))
  # The limits are inclusive.
  expect_true(BandCovers(truth, truth, truth))
  expect_false(BandCovers(truth - 0.05, truth + c(0.05, 0.05, -0.01, 0.05),
                          truth))
  expect_false(BandCovers(truth + c(0, 0, 0, 0.01), truth + 0.05, truth))
  expect_type(BandCovers(truth - 1, truth + 1, truth), "logical")
})

test_that("NearOptimalSet keeps points whose upper limit reaches the floor", {
  grid <- seq(0, 1, by = 0.1)
  j <- 1 - 2 * abs(grid - 0.5)
  out <- NearOptimalSet(grid, j - 0.15, j + 0.15, c_star = 0.5)
  # The floor is max(lower) = 0.85; upper >= 0.85 where j >= 0.7.
  expect_equal(which(out$in_set), 5:7)
  expect_equal(out$length, 3 * 0.1)
  expect_true(out$contains)
  expect_named(out, c("in_set", "length", "contains"))
})

test_that("NearOptimalSet's membership uses the interpolated upper limit", {
  grid <- seq(0, 1, by = 0.1)
  j <- 1 - 2 * abs(grid - 0.5)
  lo <- j - 0.15
  up <- j + 0.15
  expect_true(NearOptimalSet(grid, lo, up, c_star = 0.55)$contains)
  expect_false(NearOptimalSet(grid, lo, up, c_star = 0.2)$contains)
  # Between 0.3 (upper 0.75) and 0.4 (upper 0.95) the interpolated upper
  # limit crosses the floor 0.85 at 0.35.
  expect_false(NearOptimalSet(grid, lo, up, c_star = 0.34)$contains)
  expect_true(NearOptimalSet(grid, lo, up, c_star = 0.36)$contains)
})

test_that("NearOptimalSet is NA without c_star and FALSE outside the grid", {
  grid <- seq(0, 1, by = 0.1)
  j <- 1 - 2 * abs(grid - 0.5)
  expect_true(is.na(NearOptimalSet(grid, j - 0.1, j + 0.1)$contains))
  expect_false(NearOptimalSet(grid, j - 0.1, j + 0.1, c_star = 1.5)$contains)
  expect_false(NearOptimalSet(grid, j - 0.1, j + 0.1, c_star = -0.2)$contains)
  # Grid ends are inside the grid.
  expect_true(NearOptimalSet(grid, j - 1, j + 1, c_star = 0)$contains)
  expect_true(NearOptimalSet(grid, j - 1, j + 1, c_star = 1)$contains)
})

test_that("NearOptimalSet's length is points times the step", {
  grid <- seq(2, 4, by = 0.25)
  lo <- rep(0, length(grid))
  up <- rep(1, length(grid))
  out <- NearOptimalSet(grid, lo, up)
  expect_true(all(out$in_set))
  expect_equal(out$length, length(grid) * 0.25)
  # One grid point has no step.
  one <- NearOptimalSet(3, 0.2, 0.4)
  expect_equal(one$length, 0)
  expect_true(one$in_set)
})

test_that("a band that covers the curve contains its maximizer", {
  grid <- seq(-1, 3, length.out = 21)
  j <- dnorm(grid, 1, 0.8)
  c_star <- grid[which.max(j)]
  set.seed(31)
  for (i in 1:25) {
    lo <- j - runif(21, 0, 0.3)
    up <- j + runif(21, 0, 0.3)
    expect_true(BandCovers(lo, up, j))
    expect_true(NearOptimalSet(grid, lo, up, c_star)$contains)
  }
})

# -- BootOptimism -------------------------------------------------------

test_that("BootOptimism is zero for resamples equal to the original", {
  u <- 1:5
  j_bar <- c(0.1, 0.3, 0.6, 0.4, 0.2)
  boot <- rep(list(list(u = u, j_bar = j_bar)), 4)
  expect_identical(BootOptimism(boot, u, j_bar), rep(0, 4))
  # Also when the maximum is tied between intervals that lie apart: the
  # cutoff falls between them and both curves are read there.
  j_tied <- c(0.5, 0.2, 0.1, 0.2, 0.5)
  boot2 <- rep(list(list(u = u, j_bar = j_tied)), 3)
  expect_identical(BootOptimism(boot2, u, j_tied), rep(0, 3))
})

test_that("BootOptimism reads both curves at the resample's own cutoff", {
  u <- 1:5
  j_bar <- c(0.1, 0.3, 0.6, 0.4, 0.2)
  bumped <- j_bar
  bumped[3] <- bumped[3] + 0.1
  expect_equal(BootOptimism(list(list(u = u, j_bar = bumped)), u, j_bar),
               0.1)
  # A resample with its own jump points: maximizer on [3.5, 4.5), cutoff 4,
  # value 0.9; the original at 4 is 0.4.
  other <- list(u = c(1.5, 2.5, 3.5, 4.5), j_bar = c(0.2, 0.5, 0.9, 0.3))
  expect_equal(BootOptimism(list(other), u, j_bar), 0.5)
  # A cutoff below the original's first jump point reads the original as 0.
  low <- list(u = c(0, 1), j_bar = c(0.7, 0.2))
  expect_equal(BootOptimism(list(low), u, j_bar), 0.7)
  # One element per resample, in order.
  out <- BootOptimism(list(list(u = u, j_bar = bumped), other, low), u, j_bar)
  expect_equal(out, c(0.1, 0.5, 0.7))
})

test_that("BootOptimism can be negative and handles no resamples", {
  u <- 1:5
  j_bar <- c(0.1, 0.3, 0.6, 0.4, 0.2)
  # The resample peaks where the original is high but its own value there
  # is lower than the original's.
  flat <- list(u = u, j_bar = c(0.1, 0.2, 0.3, 0.2, 0.1))
  expect_equal(BootOptimism(list(flat), u, j_bar), 0.3 - 0.6)
  expect_length(BootOptimism(list(), u, j_bar), 0L)
})

# -- ResampleWithinGroups -----------------------------------------------

test_that("ResampleWithinGroups keeps the group sizes", {
  set.seed(41)
  d <- c(rep(0L, 12), rep(1L, 7), rep(0L, 3), rep(1L, 5))
  for (i in 1:20) {
    idx <- ResampleWithinGroups(d)
    expect_length(idx, length(d))
    expect_equal(sort(d[idx]), sort(d))
    expect_true(all(idx %in% seq_along(d)))
  }
})

test_that("ResampleWithinGroups draws only within each group", {
  set.seed(42)
  d <- c(1L, 0L, 0L, 1L, 1L, 0L, 1L, 1L, 0L, 0L)
  idx <- ResampleWithinGroups(d)
  n0 <- sum(d == 0)
  # Group 0 comes first, then group 1.
  expect_true(all(d[idx[seq_len(n0)]] == 0))
  expect_true(all(d[idx[-seq_len(n0)]] == 1))
  expect_true(all(idx[seq_len(n0)] %in% which(d == 0)))
  expect_true(all(idx[-seq_len(n0)] %in% which(d == 1)))
})

test_that("ResampleWithinGroups samples with replacement, uniformly", {
  set.seed(43)
  d <- rep(0:1, each = 10)
  counts <- Reduce(`+`, lapply(1:2000, function(i) {
    tabulate(ResampleWithinGroups(d), nbins = 20)
  })) / 2000
  expect_equal(counts, rep(1, 20), tolerance = 0.1)
  # Some resample repeats a subject.
  idx <- ResampleWithinGroups(rep(0:1, each = 50))
  expect_lt(length(unique(idx)), 100L)
})

test_that("ResampleWithinGroups handles a singleton group at a high index", {
  d <- c(rep(0L, 6), 1L)
  idx <- ResampleWithinGroups(d)
  expect_equal(idx[7], 7L)
  expect_true(all(idx[1:6] %in% 1:6))
})

# -- ImputeNorm and ImputeWith ------------------------------------------

test_that("ImputeNorm keeps observed values and fills the rest", {
  dat <- MissingData()
  set.seed(51)
  out <- ImputeNorm(dat$x_obs, dat$d, dat$z, 4)
  expect_equal(dim(out), c(120L, 4L))
  expect_false(anyNA(out))
  observed <- !is.na(dat$x_obs)
  for (l in 1:4) expect_equal(out[observed, l], dat$x_obs[observed])
  # The imputations differ from one another on the missing rows.
  expect_gt(sd(out[!observed, 1] - out[!observed, 2]), 0)
})

test_that("ImputeNorm draws around the regression's conditional mean", {
  dat <- MissingData()
  set.seed(52)
  out <- ImputeNorm(dat$x_obs, dat$d, dat$z, 100)
  miss <- is.na(dat$x_obs)
  # The draws are centred on the least-squares prediction of the observed
  # rows, so the mean of 100 imputations differs from it by Monte Carlo
  # error only.
  obs <- data.frame(x = dat$x_obs, d = dat$d, z = dat$z)[!miss, ]
  fit <- lm(x ~ d + z + d:z, data = obs)
  pred <- predict(fit, data.frame(d = dat$d[miss], z = dat$z[miss]))
  expect_lt(max(abs(rowMeans(out[miss, ]) - pred)), 0.15)
  # Spread near the residual SD of 0.3.
  expect_equal(mean(apply(out[miss, ], 1, sd)), 0.3, tolerance = 0.2)
})

test_that("ImputeNorm returns copies of complete data and is seeded", {
  dat <- MissingData()
  full <- ImputeNorm(dat$x, dat$d, dat$z, 3)
  expect_equal(full, matrix(dat$x, 120, 3))
  set.seed(53)
  a <- ImputeNorm(dat$x_obs, dat$d, dat$z, 2)
  set.seed(53)
  b <- ImputeNorm(dat$x_obs, dat$d, dat$z, 2)
  expect_identical(a, b)
  expect_equal(dim(ImputeNorm(dat$x_obs, dat$d, dat$z, 1)), c(120L, 1L))
})

test_that("ImputeWith 'none' returns copies of the data", {
  dat <- MissingData()
  out <- ImputeWith("none", dat$x, dat$d, dat$z, 3)
  expect_equal(dim(out), c(120L, 3L))
  for (l in 1:3) expect_identical(out[, l], dat$x)
})

test_that("ImputeWith dispatches to the named engine", {
  dat <- MissingData()
  engines <- list(pmm = ImputePmm, norm = ImputeNorm,
                  nn = ImputeNearestNeighbour)
  for (engine in names(engines)) {
    set.seed(61)
    via <- ImputeWith(engine, dat$x_obs, dat$d, dat$z, 3)
    set.seed(61)
    direct <- engines[[engine]](dat$x_obs, dat$d, dat$z, 3)
    expect_identical(via, direct)
    expect_equal(dim(via), c(120L, 3L))
    expect_false(anyNA(via))
    observed <- !is.na(dat$x_obs)
    expect_equal(via[observed, 1], dat$x_obs[observed])
  }
})

test_that("ImputeWith rejects an unknown engine", {
  dat <- MissingData()
  expect_error(ImputeWith("mean", dat$x_obs, dat$d, dat$z, 2),
               "unknown engine: mean")
})
