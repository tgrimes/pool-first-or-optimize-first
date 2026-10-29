# Tests for R/truth.R: the binormal model, its known answers, the missingness
# intercept, and the data simulator.

test_that("TrueYouden equals F0(c) - F1(c) for the binormal model", {
  cutoff <- c(-3, -1, 0, 0.7, 1, 2.4, 5)
  expect_equal(TrueYouden(cutoff, 2, 1),
               pnorm(cutoff) - pnorm((cutoff - 2) / 1), tolerance = 1e-15)
  expect_equal(TrueYouden(cutoff, 1.5, 2.5),
               pnorm(cutoff) - pnorm((cutoff - 1.5) / 2.5),
               tolerance = 1e-15)
})

test_that("TrueYouden vanishes in the tails and is symmetric if sigma1 = 1", {
  expect_equal(TrueYouden(c(-Inf, Inf), 2, 1), c(0, 0))
  expect_equal(TrueYouden(c(-Inf, Inf), 1.5, 2.5), c(0, 0))
  # With sigma1 = 1 the curve is symmetric about delta / 2.
  t <- c(0.1, 0.5, 1.3, 2.2)
  expect_equal(TrueYouden(1 + t, 2, 1), TrueYouden(1 - t, 2, 1),
               tolerance = 1e-14)
})

test_that("MarkerTruth(2, 1) has the closed-form answers", {
  mt <- MarkerTruth(2, 1)
  expect_named(mt, c("delta", "sigma1", "c_star", "j_star", "kappa", "tau"))
  expect_equal(mt$delta, 2)
  expect_equal(mt$sigma1, 1)
  expect_equal(mt$c_star, 1, tolerance = 1e-6)
  expect_equal(mt$j_star, 2 * pnorm(1) - 1, tolerance = 1e-10)
  expect_equal(mt$kappa, 2 * dnorm(1), tolerance = 1e-6)
  expect_equal(mt$tau, 0, tolerance = 1e-6)
})

test_that("MarkerTruth(1.5, 2.5) matches finite differences of TrueYouden", {
  mt <- MarkerTruth(1.5, 2.5)
  f <- function(cc) TrueYouden(cc, 1.5, 2.5)
  cs <- mt$c_star
  h <- 4e-3
  # Central second and third differences at the maximizer.
  j2 <- (f(cs + h) - 2 * f(cs) + f(cs - h)) / h^2
  j3 <- (f(cs + 2 * h) - 2 * f(cs + h) + 2 * f(cs - h) - f(cs - 2 * h)) /
    (2 * h^3)
  expect_equal(mt$kappa, -j2, tolerance = 1e-4)
  expect_equal(mt$tau, j3, tolerance = 1e-4)
  expect_gt(mt$kappa, 0)
  # The first derivative vanishes at the maximizer.
  d1 <- (f(cs + 1e-5) - f(cs - 1e-5)) / 2e-5
  expect_equal(d1, 0, tolerance = 1e-6)
})

test_that("MarkerTruth finds the global maximum of the Youden curve", {
  for (shape in list(c(2, 1), c(1.5, 2.5))) {
    mt <- MarkerTruth(shape[1], shape[2])
    grid <- seq(-6, 14, by = 0.001)
    j_grid <- TrueYouden(grid, shape[1], shape[2])
    expect_equal(mt$j_star, max(j_grid), tolerance = 1e-6)
    expect_equal(mt$c_star, grid[which.max(j_grid)], tolerance = 2e-3)
    expect_equal(mt$j_star, TrueYouden(mt$c_star, shape[1], shape[2]))
  }
})

# Expected missing fraction, by a trapezoid sum over a fine grid of Z, a
# different quadrature from the integrate() the function uses.
ExpectedMissing <- function(alpha0, delta, sigma1, b_z = 1, b_d = 0.5) {
  z <- seq(-14, 16, by = 0.002)
  w <- 0.002
  m0 <- sum(plogis(alpha0 + b_z * z) * dnorm(z, 0, sqrt(2))) * w
  m1 <- sum(plogis(alpha0 + b_z * z + b_d) *
              dnorm(z, delta, sqrt(sigma1^2 + 1))) * w
  (m0 + m1) / 2
}

test_that("MissingIntercept hits the target expected missing fraction", {
  for (rate in c(0.2, 0.4, 0.6)) {
    a_sharp <- MissingIntercept(rate, 2, 1)
    a_flat <- MissingIntercept(rate, 1.5, 2.5)
    expect_equal(ExpectedMissing(a_sharp, 2, 1), rate, tolerance = 1e-6)
    expect_equal(ExpectedMissing(a_flat, 1.5, 2.5), rate, tolerance = 1e-6)
  }
  # Non-default coefficients.
  a <- MissingIntercept(0.3, 2, 1, b_z = 0.5, b_d = -0.25)
  expect_equal(ExpectedMissing(a, 2, 1, b_z = 0.5, b_d = -0.25), 0.3,
               tolerance = 1e-6)
})

test_that("MissingIntercept increases with the target rate and checks it", {
  rates <- c(0.1, 0.25, 0.4, 0.6, 0.8)
  alphas <- vapply(rates, MissingIntercept, numeric(1), delta = 2, sigma1 = 1)
  expect_true(all(diff(alphas) > 0))
  expect_error(MissingIntercept(0, 2, 1))
  expect_error(MissingIntercept(1, 2, 1))
  expect_error(MissingIntercept(-0.1, 2, 1))
})

test_that("SimulateMarkerData has the right sizes, columns and NA pattern", {
  set.seed(101)
  alpha0 <- MissingIntercept(0.4, 2, 1)
  dat <- SimulateMarkerData(50, 2, 1, alpha0)
  expect_s3_class(dat, "data.frame")
  expect_equal(dim(dat), c(100L, 5L))
  expect_named(dat, c("d", "x_full", "z", "observed", "x"))
  expect_equal(as.vector(table(dat$d)), c(50L, 50L))
  expect_equal(dat$d, rep(c(0L, 1L), each = 50))
  expect_type(dat$observed, "logical")
  expect_identical(is.na(dat$x), !dat$observed)
  expect_equal(dat$x[dat$observed], dat$x_full[dat$observed])
  expect_false(anyNA(dat$x_full))
  expect_false(anyNA(dat$z))
})

test_that("SimulateMarkerData with alpha0 = NA has no missing values", {
  set.seed(102)
  dat <- SimulateMarkerData(40, 1.5, 2.5)
  expect_true(all(dat$observed))
  expect_false(anyNA(dat$x))
  expect_equal(dat$x, dat$x_full)
  dat2 <- SimulateMarkerData(40, 1.5, 2.5, alpha0 = NA_real_)
  expect_false(anyNA(dat2$x))
})

test_that("SimulateMarkerData follows the binormal and MAR model", {
  set.seed(103)
  n <- 20000
  alpha0 <- MissingIntercept(0.4, 2, 1)
  dat <- SimulateMarkerData(n, 2, 1, alpha0)
  # Marker moments by group (Monte Carlo SE about 0.007 each).
  expect_equal(mean(dat$x_full[dat$d == 0]), 0, tolerance = 0.05)
  expect_equal(sd(dat$x_full[dat$d == 0]), 1, tolerance = 0.03)
  expect_equal(mean(dat$x_full[dat$d == 1]), 2, tolerance = 0.05)
  # Auxiliary Z = X + e with e ~ N(0, 1).
  expect_equal(sd(dat$z - dat$x_full), 1, tolerance = 0.03)
  # The realized missing fraction is near the target (SE about 0.0025).
  expect_lt(abs(mean(!dat$observed) - 0.4), 0.02)
  # Missing at random through Z: a larger Z goes with more missingness.
  expect_gt(mean(dat$z[!dat$observed]), mean(dat$z[dat$observed]) + 0.3)
  # Disease status (b_d = 0.5) also raises the missing probability, given Z.
  fit <- glm(!observed ~ z + d, data = dat, family = binomial())
  expect_equal(unname(coef(fit)["z"]), 1, tolerance = 0.1)
  expect_equal(unname(coef(fit)["d"]), 0.5, tolerance = 0.15)
  expect_equal(unname(coef(fit)["(Intercept)"]), alpha0, tolerance = 0.15)
})

test_that("SimulateMarkerData is reproducible under a seed", {
  set.seed(7)
  a <- SimulateMarkerData(30, 2, 1, -1.9)
  set.seed(7)
  b <- SimulateMarkerData(30, 2, 1, -1.9)
  expect_identical(a, b)
})
