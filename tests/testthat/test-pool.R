# Tests for R/pool.R: exact pooling of identical inputs, the three pooling
# rules (P1, P2, P3) for step and smooth curves, and Rubin's rules.

# Completed data: L imputations of 2 * n subjects.
RandomCompleted <- function(n = 20, n_imp = 5) {
  d <- rep(0:1, each = n)
  list(d = d,
       completed = matrix(rnorm(2 * n * n_imp, mean = d, sd = 1 + d / 2),
                          nrow = 2 * n))
}

# Quadratic curves f_l(c) = a_l - b_l (c - m_l)^2, with closed-form pools.
QuadraticCurves <- function(a, b, m) {
  function(cutoff, l) a[l] - b[l] * (cutoff - m[l])^2
}

test_that("PoolMean equals mean() for vectors", {
  set.seed(1)
  for (n in c(1, 2, 5, 20)) {
    v <- rnorm(n, 3, 2)
    expect_equal(PoolMean(v), mean(v), tolerance = 1e-14)
  }
  expect_equal(PoolMean(5), 5)
})

test_that("PoolMean equals colMeans() for matrices", {
  set.seed(2)
  m <- matrix(rnorm(7 * 11), nrow = 7)
  expect_equal(PoolMean(m), colMeans(m), tolerance = 1e-14)
  expect_length(PoolMean(m), 11)
  one <- matrix(c(1.5, 2.5, 3.5), nrow = 1)
  expect_equal(PoolMean(one), c(1.5, 2.5, 3.5))
})

test_that("PoolMean returns v[1] exactly for identical inputs", {
  for (value in c(0.1, 0.1 + 0.2, 1 / 3, 0.7)) {
    for (n in c(2, 3, 7, 20, 100)) {
      expect_identical(PoolMean(rep(value, n)), value)
    }
  }
  m <- matrix(rep(c(0.1, 1 / 3, 0.7), each = 20), nrow = 20)
  expect_identical(PoolMean(m), c(0.1, 1 / 3, 0.7))
  m_named <- matrix(rep(c(0.1, 1 / 3), each = 9), nrow = 9,
                    dimnames = list(NULL, c("a", "b")))
  expect_identical(PoolMean(m_named), m_named[1, ])
})

test_that("CollectRules combines the rules' cutoffs, indices and B_c", {
  c_l <- c(1, 2, 6)
  m_l <- c(0.5, 0.6, 0.7)
  out <- micutoff:::CollectRules(c_l, m_l, list(cutoff = 2.5, value = 0.4),
                                 p3_cutoff = 2, p3_index = 0.45)
  expect_equal(out$cutoff, c(p1 = 2.5, p2 = 3, p3 = 2))
  expect_equal(out$index, c(p1 = 0.4, p2 = 0.6, p3 = 0.45))
  # B_c is the (divide-by-L) variance of the per-dataset cutoffs.
  expect_equal(out$b_c, mean((c_l - 3)^2))
  expect_equal(out$c_l, c_l)
  expect_equal(out$m_l, m_l)
})

test_that("PoolStepCurves gives the hand-computed answers", {
  u <- 1:4
  values <- rbind(c(0, 0.6, 0.2, 0), c(0, 0.2, 0.6, 0))
  out <- PoolStepCurves(u, values)
  # Dataset cutoffs 2.5 and 3.5, both maxima 0.6; the averaged curve is
  # (0, 0.4, 0.4, 0), tied on intervals 2 and 3: cutoff 3, value 0.4.
  expect_equal(out$c_l, c(2.5, 3.5), ignore_attr = TRUE)
  expect_equal(out$m_l, c(0.6, 0.6), ignore_attr = TRUE)
  expect_equal(out$j_bar, c(0, 0.4, 0.4, 0))
  expect_equal(out$cutoff, c(p1 = 3, p2 = 3, p3 = 3))
  expect_equal(out$index, c(p1 = 0.4, p2 = 0.6, p3 = 0.4))
  expect_equal(out$b_c, 0.25)
  expect_equal(out$index[["p2"]] - out$index[["p1"]], 0.2)
})

test_that("PoolStepCurves matches the rules computed literally", {
  set.seed(3)
  dd <- RandomCompleted(n = 25, n_imp = 6)
  curves <- EmpiricalCurves(dd$completed, dd$d)
  out <- PoolStepCurves(curves$u, curves$values)
  per <- lapply(seq_len(6), function(l) {
    MaximizeStep(curves$u, curves$values[l, ])
  })
  c_l <- vapply(per, `[[`, numeric(1), "cutoff")
  m_l <- vapply(per, `[[`, numeric(1), "value")
  j_bar <- colMeans(curves$values)
  p1 <- MaximizeStep(curves$u, j_bar)
  expect_equal(out$j_bar, j_bar, tolerance = 1e-14)
  expect_equal(out$cutoff[["p1"]], p1$cutoff, tolerance = 1e-12)
  expect_equal(out$index[["p1"]], p1$value, tolerance = 1e-12)
  expect_equal(out$cutoff[["p2"]], mean(c_l), tolerance = 1e-12)
  expect_equal(out$index[["p2"]], mean(m_l), tolerance = 1e-12)
  # P3: the median of the dataset cutoffs, with the averaged curve there.
  expect_equal(out$cutoff[["p3"]], median(c_l))
  expect_equal(out$index[["p3"]],
               StepValue(median(c_l), curves$u, j_bar), tolerance = 1e-12)
  expect_equal(out$b_c, mean((c_l - mean(c_l))^2), tolerance = 1e-12)
  expect_named(out$cutoff, c("p1", "p2", "p3"))
  expect_named(out$index, c("p1", "p2", "p3"))
})

test_that("PoolStepCurves of identical curves: same cutoffs, gap 0", {
  set.seed(4)
  d <- rep(0:1, each = 30)
  x <- rnorm(60, mean = d, sd = 1 + d / 2)
  for (n_imp in c(2, 5, 20)) {
    completed <- matrix(x, nrow = 60, ncol = n_imp)
    curves <- EmpiricalCurves(completed, d)
    out <- PoolStepCurves(curves$u, curves$values)
    expect_identical(out$cutoff[["p1"]], out$cutoff[["p2"]])
    expect_identical(out$cutoff[["p1"]], out$cutoff[["p3"]])
    expect_identical(out$index[["p2"]] - out$index[["p1"]], 0)
    expect_identical(out$index[["p3"]] - out$index[["p1"]], 0)
    expect_equal(out$b_c, 0)
  }
})

test_that("the P2 - P1 gap is non-negative on random step curves", {
  set.seed(5)
  for (rep in 1:40) {
    dd <- RandomCompleted(n = 15, n_imp = 4)
    curves <- EmpiricalCurves(dd$completed, dd$d)
    out <- PoolStepCurves(curves$u, curves$values)
    # The mean of the maxima is at least the maximum of the mean.
    expect_gte(out$index[["p2"]] - out$index[["p1"]], -1e-12)
    expect_gte(out$b_c, 0)
  }
  # Arbitrary step curves, not only Youden curves.
  u <- seq_len(30)
  for (rep in 1:40) {
    values <- matrix(runif(5 * 30), nrow = 5)
    out <- PoolStepCurves(u, values)
    expect_gte(out$index[["p2"]] - out$index[["p1"]], -1e-12)
  }
})

test_that("MaximizeSmooth finds the vertex of a parabola", {
  f <- function(x) 2 - (x - 1.3)^2
  grid <- seq(-1, 3, length.out = 21)
  out <- micutoff:::MaximizeSmooth(f, grid, f(grid))
  expect_equal(out$cutoff, 1.3, tolerance = 1e-6)
  expect_equal(out$value, 2, tolerance = 1e-10)
  expect_named(out, c("cutoff", "value"))
})

test_that("MaximizeSmooth keeps the grid point if optimize() does worse", {
  f <- function(x) 2 - (x - 1.3)^2
  grid <- seq(-1, 3, length.out = 21)
  # Pretend the grid values are higher than f: the grid point wins.
  fake <- f(grid) + 1
  out <- micutoff:::MaximizeSmooth(f, grid, fake)
  k <- which.max(fake)
  expect_equal(out$cutoff, grid[k])
  expect_equal(out$value, fake[k])
})

test_that("MaximizeSmooth handles a maximum at the edge of the grid", {
  f <- function(x) -x
  grid <- seq(0, 2, length.out = 11)
  out <- micutoff:::MaximizeSmooth(f, grid, f(grid))
  expect_equal(out$cutoff, 0, tolerance = 1e-6)
  expect_equal(out$value, 0, tolerance = 1e-6)
  g <- function(x) x
  out2 <- micutoff:::MaximizeSmooth(g, grid, g(grid))
  expect_equal(out2$cutoff, 2, tolerance = 1e-6)
})

test_that("PoolSmoothCurves matches the closed form for quadratic curves", {
  a <- c(1.0, 1.2, 0.9, 1.1)
  b <- c(0.5, 1.0, 0.7, 0.3)
  m <- c(0.2, 0.6, -0.1, 0.9)
  curve_fun <- QuadraticCurves(a, b, m)
  grid <- seq(-2, 3, length.out = 51)
  out <- PoolSmoothCurves(curve_fun, 4, grid)
  # The averaged curve is a quadratic with leading coefficient mean(b).
  p1_cutoff <- mean(b * m) / mean(b)
  p1_value <- mean(a) - mean(b * m^2) + mean(b * m)^2 / mean(b)
  expect_equal(out$cutoff[["p1"]], p1_cutoff, tolerance = 1e-6)
  expect_equal(out$index[["p1"]], p1_value, tolerance = 1e-10)
  expect_equal(out$cutoff[["p2"]], mean(m), tolerance = 1e-6)
  expect_equal(out$index[["p2"]], mean(a), tolerance = 1e-10)
  expect_equal(out$cutoff[["p3"]], median(m), tolerance = 1e-6)
  expect_equal(out$index[["p3"]], out$j_bar_fun(median(m)))
  expect_equal(out$b_c, mean((m - mean(m))^2), tolerance = 1e-6)
  # The gap is the b-weighted variance of the maximizers.
  gap <- out$index[["p2"]] - out$index[["p1"]]
  expect_equal(gap, mean(b * m^2) - mean(b * m)^2 / mean(b),
               tolerance = 1e-8)
  expect_gt(gap, 0)
  # The averaged curve function is the mean of the curves.
  expect_equal(out$j_bar_fun(0.4), mean(a - b * (0.4 - m)^2))
})

test_that("PoolSmoothCurves accepts precomputed grid values", {
  a <- c(1.0, 1.2, 0.9)
  b <- c(0.5, 1.0, 0.7)
  m <- c(0.2, 0.6, -0.1)
  curve_fun <- QuadraticCurves(a, b, m)
  grid <- seq(-2, 3, length.out = 51)
  gv <- t(vapply(1:3, function(l) curve_fun(grid, l), numeric(51)))
  with_gv <- PoolSmoothCurves(curve_fun, 3, grid, gv)
  without <- PoolSmoothCurves(curve_fun, 3, grid)
  expect_equal(with_gv$cutoff, without$cutoff, tolerance = 1e-12)
  expect_equal(with_gv$index, without$index, tolerance = 1e-12)
})

test_that("PoolSmoothCurves of identical kernel curves has gap exactly 0", {
  set.seed(6)
  d <- rep(0:1, each = 40)
  x <- rnorm(80, mean = 1.5 * d)
  for (n_imp in c(3, 10)) {
    completed <- matrix(x, nrow = 80, ncol = n_imp)
    kc <- KernelCurves(completed, d)
    grid <- seq(quantile(x, 0.005), quantile(x, 0.995), length.out = 101)
    out <- PoolSmoothCurves(kc$curve_fun, n_imp, grid, kc$grid_fun(grid))
    expect_identical(out$cutoff[["p1"]], out$cutoff[["p2"]])
    expect_identical(out$cutoff[["p1"]], out$cutoff[["p3"]])
    expect_identical(out$index[["p2"]] - out$index[["p1"]], 0)
    expect_equal(out$b_c, 0)
  }
})

test_that("the P2 - P1 gap is non-negative on random kernel curves", {
  set.seed(7)
  for (rep in 1:8) {
    dd <- RandomCompleted(n = 30, n_imp = 4)
    kc <- KernelCurves(dd$completed, dd$d)
    grid <- seq(quantile(dd$completed, 0.01), quantile(dd$completed, 0.99),
                length.out = 101)
    out <- PoolSmoothCurves(kc$curve_fun, 4, grid, kc$grid_fun(grid))
    expect_gte(out$index[["p2"]] - out$index[["p1"]], -1e-10)
    expect_gte(out$b_c, 0)
    # The P1 maximum is no smaller than the averaged curve on the grid.
    expect_gte(out$index[["p1"]],
               max(colMeans(kc$grid_fun(grid))) - 1e-12)
  }
})

test_that("RubinInterval reproduces a hand computation", {
  q <- c(1, 2, 3)
  u <- c(0.5, 0.5, 0.5)
  ri <- RubinInterval(q, u)
  # U-bar = 0.5, B = var(q) = 1, T = 0.5 + (4/3) * 1 = 11/6,
  # df = 2 * (1 + 0.5 / (4/3))^2 = 2 * (11/8)^2 = 121/32.
  expect_equal(ri$estimate, 2)
  expect_equal(ri$se^2, 11 / 6)
  expect_equal(ri$df, 121 / 32)
  half <- qt(0.975, 121 / 32) * sqrt(11 / 6)
  expect_equal(ri$lower, 2 - half)
  expect_equal(ri$upper, 2 + half)
  expect_named(ri, c("estimate", "se", "df", "lower", "upper"))
})

test_that("RubinInterval honours the confidence level", {
  q <- c(0.30, 0.36, 0.33, 0.31)
  u <- c(0.0004, 0.0005, 0.0006, 0.0005)
  ri <- RubinInterval(q, u, level = 0.90)
  t_var <- mean(u) + (1 + 1 / 4) * var(q)
  df <- 3 * (1 + mean(u) / ((1 + 1 / 4) * var(q)))^2
  expect_equal(ri$se^2, t_var)
  expect_equal(ri$df, df)
  expect_equal(ri$upper - ri$estimate, qt(0.95, df) * sqrt(t_var))
  expect_equal(ri$estimate - ri$lower, qt(0.95, df) * sqrt(t_var))
  wider <- RubinInterval(q, u, level = 0.99)
  expect_gt(wider$upper - wider$lower, ri$upper - ri$lower)
})

test_that("RubinInterval with B = 0 has infinite df and normal limits", {
  q <- rep(0.25, 4)
  u <- c(0.01, 0.03, 0.02, 0.02)
  ri <- RubinInterval(q, u)
  expect_identical(ri$estimate, 0.25)
  expect_equal(ri$df, Inf)
  expect_equal(ri$se, sqrt(0.02))
  expect_equal(ri$lower, 0.25 - qnorm(0.975) * sqrt(0.02))
  expect_equal(ri$upper, 0.25 + qnorm(0.975) * sqrt(0.02))
})

test_that("RubinInterval with one imputation reduces to the usual interval", {
  ri <- RubinInterval(0.4, 0.0025)
  expect_equal(ri$df, Inf)
  expect_equal(ri$se, 0.05)
  expect_equal(ri$lower, 0.4 - qnorm(0.975) * 0.05)
  expect_equal(ri$upper, 0.4 + qnorm(0.975) * 0.05)
})

test_that("RubinInterval covers at about the nominal rate (Monte Carlo)", {
  set.seed(8)
  truth <- 0.5
  n_sim <- 1000
  hits <- vapply(seq_len(n_sim), function(i) {
    # A common error with sd 0.03 (the complete-data sampling error, so
    # U = 0.03^2) plus imputation noise with sd 0.02 around it.
    common <- rnorm(1, 0, 0.03)
    q <- truth + common + rnorm(5, 0, 0.02)
    ri <- RubinInterval(q, rep(0.03^2, 5))
    ri$lower <= truth && truth <= ri$upper
  }, logical(1))
  # Nominal 0.95. Here T = U + 1.2 B overstates the variance of the pooled
  # estimate, U + B / 5, so the interval is conservative.
  expect_gt(mean(hits), 0.93)
})
