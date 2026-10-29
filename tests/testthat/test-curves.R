# Tests for R/curves.R: empirical step curves, kernel curves, and the
# helpers that read them.

# Literal empirical Youden curve at one threshold of one dataset.
LiteralEmpirical <- function(cutoff, x, d) {
  mean(x[d == 0] <= cutoff) - mean(x[d == 1] <= cutoff)
}

# Completed datasets with ties (integer-valued) so the step curve is tested
# where it is hardest.
TiedCompleted <- function(n = 12, n_imp = 3) {
  matrix(sample(1:6, 2 * n * n_imp, replace = TRUE), nrow = 2 * n)
}

test_that("EmpiricalCurves equals the literal F0 - F1 at the jump points", {
  set.seed(1)
  d <- rep(c(0, 1), times = c(10, 14))
  completed <- TiedCompleted(n = 12, n_imp = 4)
  expect_equal(nrow(completed), length(d))
  curves <- EmpiricalCurves(completed, d)
  expect_equal(curves$u, sort(unique(as.vector(completed))))
  expect_equal(dim(curves$values), c(4L, length(curves$u)))
  for (l in 1:4) {
    for (k in seq_along(curves$u)) {
      expect_equal(curves$values[l, k],
                   LiteralEmpirical(curves$u[k], completed[, l], d))
    }
  }
})

test_that("EmpiricalCurves is zero at the largest jump point", {
  set.seed(2)
  d <- rep(0:1, each = 15)
  completed <- matrix(rnorm(30 * 3), nrow = 30)
  curves <- EmpiricalCurves(completed, d)
  expect_equal(length(curves$u), 30 * 3)
  expect_equal(curves$values[, ncol(curves$values)], rep(0, 3))
  expect_true(all(abs(curves$values) <= 1))
})

test_that("EmpiricalCurves works for one dataset and for a data frame", {
  set.seed(3)
  d <- rep(0:1, each = 8)
  x <- rnorm(16)
  one <- EmpiricalCurves(matrix(x), d)
  expect_equal(dim(one$values), c(1L, 16L))
  expect_equal(one$u, sort(x))
  expect_equal(one$values[1, ], vapply(one$u, LiteralEmpirical, numeric(1),
                                       x = x, d = d))
  from_df <- EmpiricalCurves(data.frame(a = x, b = x + 1), d)
  expect_equal(nrow(from_df$values), 2L)
})

test_that("MaximizeStep finds a unique maximum at the interval midpoint", {
  u <- 1:5
  v <- c(0.1, 0.5, 0.2, 0.3, 0)
  out <- MaximizeStep(u, v)
  expect_equal(out$cutoff, 2.5)
  expect_equal(out$value, 0.5)
  expect_named(out, c("cutoff", "value"))
})

test_that("MaximizeStep averages the midpoints of tied maxima", {
  u <- 1:6
  v <- c(0.1, 0.5, 0.2, 0.5, 0, 0.5)
  out <- MaximizeStep(u, v)
  # Midpoints 2.5, 4.5, and 6 (the last interval is the single point u[6]).
  expect_equal(out$cutoff, mean(c(2.5, 4.5, 6)))
  expect_equal(out$value, 0.5)
  # Ties within the tolerance count; clear differences do not.
  expect_equal(MaximizeStep(1:3, c(0.3, 0.3 + 5e-13, 0))$cutoff,
               mean(c(1.5, 2.5)))
  expect_equal(MaximizeStep(1:3, c(0.3, 0.3 + 1e-9, 0))$cutoff, 2.5)
})

test_that("MaximizeStep at the last jump point returns that point", {
  out <- MaximizeStep(c(0, 1, 2), c(0, 0.1, 0.9))
  expect_equal(out$cutoff, 2)
  expect_equal(out$value, 0.9)
})

test_that("StepValue is 0 below the first point and right-continuous", {
  u <- c(1, 2, 3)
  v <- c(0.1, 0.5, 0.2)
  expect_equal(StepValue(0.5, u, v), 0)
  expect_equal(StepValue(c(0.5, 1, 1.5, 2, 2.9, 3, 10), u, v),
               c(0, 0.1, 0.1, 0.5, 0.5, 0.2, 0.2))
  expect_equal(StepValue(numeric(0), u, v), numeric(0))
})

test_that("StepValue reproduces the empirical curve between jump points", {
  set.seed(4)
  d <- rep(0:1, each = 20)
  x <- rnorm(40)
  curves <- EmpiricalCurves(matrix(x), d)
  cutoffs <- c(-3, runif(25, -2, 2), 3)
  got <- StepValue(cutoffs, curves$u, curves$values[1, ])
  want <- vapply(cutoffs, LiteralEmpirical, numeric(1), x = x, d = d)
  expect_equal(got, want)
})

test_that("KernelCdf matches a literal sum of normal CDFs", {
  set.seed(5)
  x <- rnorm(15)
  h <- 0.37
  cutoff <- c(-2, -0.4, 0, 0.9, 3)
  literal <- vapply(cutoff, function(cc) {
    total <- 0
    for (i in seq_along(x)) total <- total + pnorm((cc - x[i]) / h)
    total / length(x)
  }, numeric(1))
  expect_equal(KernelCdf(cutoff, x, h), literal, tolerance = 1e-10)
})

test_that("KernelCdf is a distribution function", {
  set.seed(6)
  x <- rnorm(30)
  grid <- seq(-6, 6, length.out = 200)
  f <- KernelCdf(grid, x, bw.nrd0(x))
  expect_true(all(diff(f) >= 0))
  expect_equal(f[1], 0, tolerance = 1e-8)
  expect_equal(f[200], 1, tolerance = 1e-8)
  # A vanishing bandwidth recovers the empirical CDF.
  expect_equal(KernelCdf(c(-0.5, 0.5), x, 1e-6),
               c(mean(x <= -0.5), mean(x <= 0.5)))
})

test_that("KernelCurves uses a Silverman bandwidth per group and dataset", {
  set.seed(7)
  d <- rep(0:1, times = c(25, 35))
  completed <- cbind(rnorm(60), rnorm(60, 1, 2), rnorm(60, -1))
  kc <- KernelCurves(completed, d)
  expect_length(kc$h0, 3)
  expect_length(kc$h1, 3)
  for (l in 1:3) {
    expect_equal(kc$h0[[l]], bw.nrd0(completed[d == 0, l]))
    expect_equal(kc$h1[[l]], bw.nrd0(completed[d == 1, l]))
  }
  expect_type(kc$curve_fun, "closure")
  expect_type(kc$grid_fun, "closure")
})

test_that("KernelCurves' curve_fun is a literal F0 - F1 smoother", {
  set.seed(8)
  d <- rep(0:1, times = c(20, 25))
  completed <- cbind(rnorm(45), rnorm(45, 0.5))
  kc <- KernelCurves(completed, d)
  for (l in 1:2) {
    for (cc in c(-1, 0.3, 1.2)) {
      f0 <- KernelCdf(cc, completed[d == 0, l], kc$h0[[l]])
      f1 <- KernelCdf(cc, completed[d == 1, l], kc$h1[[l]])
      expect_equal(kc$curve_fun(cc, l), f0 - f1, tolerance = 1e-10)
    }
  }
  # Several indices at once.
  expect_equal(kc$curve_fun(0.3, 1:2),
               c(kc$curve_fun(0.3, 1), kc$curve_fun(0.3, 2)))
})

test_that("KernelCurves' grid_fun agrees with curve_fun on the grid", {
  set.seed(9)
  d <- rep(0:1, each = 30)
  completed <- cbind(rnorm(60), rnorm(60, 1), rnorm(60, 0, 2))
  kc <- KernelCurves(completed, d)
  grid <- seq(-2, 3, length.out = 17)
  gv <- kc$grid_fun(grid)
  expect_equal(dim(gv), c(3L, 17L))
  for (j in seq_along(grid)) {
    expect_equal(gv[, j], kc$curve_fun(grid[j], 1:3), tolerance = 1e-10)
  }
  one <- KernelCurves(completed[, 1, drop = FALSE], d)$grid_fun(grid)
  expect_equal(dim(one), c(1L, 17L))
})

test_that("GroupCdfAt (empirical) matches literal group proportions", {
  set.seed(10)
  d <- rep(0:1, times = c(14, 18))
  completed <- TiedCompleted(n = 16, n_imp = 3)
  for (cc in c(0, 2, 2.5, 6)) {
    out <- GroupCdfAt(cc, completed, d, "empirical")
    expect_equal(dim(out), c(3L, 2L))
    expect_equal(colnames(out), c("f0", "f1"))
    for (l in 1:3) {
      expect_equal(unname(out[l, "f0"]), mean(completed[d == 0, l] <= cc))
      expect_equal(unname(out[l, "f1"]), mean(completed[d == 1, l] <= cc))
    }
  }
})

test_that("GroupCdfAt (kernel) matches literal kernel CDFs", {
  set.seed(11)
  d <- rep(0:1, times = c(22, 28))
  completed <- cbind(rnorm(50), rnorm(50, 1, 1.5))
  kc <- KernelCurves(completed, d)
  for (cc in c(-1, 0.4, 2)) {
    out <- GroupCdfAt(cc, completed, d, "kernel", kc$h0, kc$h1)
    expect_equal(colnames(out), c("f0", "f1"))
    for (l in 1:2) {
      expect_equal(unname(out[l, "f0"]),
                   mean(pnorm((cc - completed[d == 0, l]) / kc$h0[[l]])),
                   tolerance = 1e-10)
      expect_equal(unname(out[l, "f1"]),
                   mean(pnorm((cc - completed[d == 1, l]) / kc$h1[[l]])),
                   tolerance = 1e-10)
    }
    # And f0 - f1 is the smooth Youden curve.
    expect_equal(out[, "f0"] - out[, "f1"], kc$curve_fun(cc, 1:2),
                 tolerance = 1e-10)
  }
})

test_that("GroupCdfAt differences reproduce the empirical Youden curve", {
  set.seed(12)
  d <- rep(0:1, each = 10)
  completed <- cbind(rnorm(20), rnorm(20))
  curves <- EmpiricalCurves(completed, d)
  cc <- 0.15
  out <- GroupCdfAt(cc, completed, d, "empirical")
  for (l in 1:2) {
    expect_equal(unname(out[l, "f0"] - out[l, "f1"]),
                 StepValue(cc, curves$u, curves$values[l, ]))
  }
})
