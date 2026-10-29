# Tests for R/inference_c.R: pilot-c's grid from the completed values, the
# covariance split, and the comparison-based near-optimal set
# (pilot-c/preregistration.md, section 2).

# -- Helpers, written apart from R/inference_c.R ------------------------

# `m` matrices of R_B x K curves: a resample-level curve shared by the
# imputations (columns correlated 0.5) plus independent imputation noise.
FakeBootCurves <- function(r_b = 300L, k_n = 4L, m = 2L, sd_w = 0.5) {
  shared <- matrix(stats::rnorm(r_b * k_n), r_b) %*%
    chol(0.5 * diag(k_n) + 0.5)
  lapply(seq_len(m), function(l) {
    shared + sd_w * matrix(stats::rnorm(r_b * k_n), r_b)
  })
}

# V, W, and the unclipped V - W/m + W/L, by explicit loops.
LiteralSplit <- function(boot_curves, n_imp) {
  m <- length(boot_curves)
  r_b <- nrow(boot_curves[[1]])
  k_n <- ncol(boot_curves[[1]])
  boot_mean <- matrix(0, r_b, k_n)
  for (l in seq_len(m)) boot_mean <- boot_mean + boot_curves[[l]] / m
  centre <- colMeans(boot_mean)
  v <- matrix(0, k_n, k_n)
  w <- matrix(0, k_n, k_n)
  for (b in seq_len(r_b)) {
    dev <- boot_mean[b, ] - centre
    v <- v + outer(dev, dev) / (r_b - 1)
    if (m > 1) {
      for (l in seq_len(m)) {
        dev_w <- boot_curves[[l]][b, ] - boot_mean[b, ]
        w <- w + outer(dev_w, dev_w) / (r_b * (m - 1))
      }
    }
  }
  list(v = v, w = w, raw = v - w / m + w / n_imp)
}

# The smallest eigenvalue of a symmetric matrix.
MinEigen <- function(x) min(eigen(x, symmetric = TRUE)$values)

# The critical value by explicit loops over grid points and draws.
LiteralCritical <- function(draws, cov_scale, level) {
  k_n <- ncol(draws)
  q_k <- rep(-Inf, k_n)
  for (k in seq_len(k_n)) {
    others <- setdiff(seq_len(k_n), k)
    s <- vapply(others, function(j) {
      sqrt(max(cov_scale[j, j] + cov_scale[k, k] - 2 * cov_scale[j, k], 0))
    }, numeric(1))
    use <- s > 0
    if (!any(use)) next
    others <- others[use]
    s <- s[use]
    stat <- numeric(nrow(draws))
    for (i in seq_len(nrow(draws))) {
      stat[i] <- max((draws[i, others] - draws[i, k]) / s)
    }
    q_k[k] <- stats::quantile(stat, level, type = 7, names = FALSE)
  }
  max(q_k)
}

# The comparison-based set by a double loop.
LiteralSet <- function(estimate, sigma, q) {
  k_n <- length(estimate)
  in_set <- rep(TRUE, k_n)
  for (k in seq_len(k_n)) {
    for (j in seq_len(k_n)) {
      if (j == k) next
      s <- sqrt(max(sigma[j, j] + sigma[k, k] - 2 * sigma[j, k], 0))
      if (estimate[j] - estimate[k] > q * s) in_set[k] <- FALSE
    }
  }
  in_set
}

# A random positive-definite covariance matrix.
RandomSigma <- function(k_n) {
  a <- matrix(stats::rnorm(k_n * (k_n + 3)), k_n)
  tcrossprod(a) / (k_n + 3)
}

# The covariance split of six grid points whose first three carry identical
# curves in every resample and imputation, as when no completed value lies
# between them (a pile-up at a limit of detection, or PMM donors).
TiedSplit <- function() {
  curves <- lapply(FakeBootCurves(r_b = 200L, k_n = 4L, m = 2L), function(x) {
    0.05 * cbind(x[, 1], x[, 1], x[, 1], x[, 2:4])
  })
  CovarianceSplit(curves, 20L)
}

# -- GridFromCompleted ----------------------------------------------------

test_that("GridFromCompleted spans the 10% and 90% quantiles of all values", {
  set.seed(1)
  completed <- matrix(stats::rnorm(200), 50, 4)
  grid <- GridFromCompleted(completed)
  expect_length(grid, 41L)
  q <- stats::quantile(as.vector(completed), c(0.1, 0.9), names = FALSE)
  expect_equal(grid[1], q[1])
  expect_equal(grid[41], q[2])
  expect_true(all(diff(grid) > 0))
  # Equally spaced.
  expect_equal(diff(grid), rep(diff(grid)[1], 40))
})

test_that("GridFromCompleted pools all imputations, however many", {
  set.seed(2)
  completed <- matrix(stats::rexp(150), 30, 5)
  grid <- GridFromCompleted(completed, grid_n = 11L)
  expect_length(grid, 11L)
  all_values <- c(completed[, 1], completed[, 2], completed[, 3],
                  completed[, 4], completed[, 5])
  q <- stats::quantile(all_values, c(0.1, 0.9), names = FALSE)
  expect_equal(c(grid[1], grid[11]), q)
  # A single completed dataset (the null cell's copies are all alike).
  one <- GridFromCompleted(completed[, 1, drop = FALSE], grid_n = 5L)
  q1 <- stats::quantile(completed[, 1], c(0.1, 0.9), names = FALSE)
  expect_equal(c(one[1], one[5]), q1)
})

test_that("GridFromCompleted takes other quantiles and ignores the layout", {
  set.seed(3)
  completed <- matrix(stats::rnorm(120), 40, 3)
  grid <- GridFromCompleted(completed, grid_n = 7L, probs = c(0.25, 0.75))
  q <- stats::quantile(as.vector(completed), c(0.25, 0.75), names = FALSE)
  expect_equal(c(grid[1], grid[7]), q)
  # Identical imputations give the same grid as one copy.
  copies <- matrix(completed[, 1], 40, 4)
  expect_equal(GridFromCompleted(copies),
               GridFromCompleted(completed[, 1, drop = FALSE]))
})

# -- CovarianceSplit ------------------------------------------------------

test_that("CovarianceSplit returns its four parts with the right shapes", {
  set.seed(10)
  cs <- CovarianceSplit(FakeBootCurves(r_b = 50L, k_n = 3L, m = 2L), 20L)
  expect_named(cs, c("sigma", "v", "w", "boot_mean"))
  expect_equal(dim(cs$sigma), c(3L, 3L))
  expect_equal(dim(cs$v), c(3L, 3L))
  expect_equal(dim(cs$w), c(3L, 3L))
  expect_equal(dim(cs$boot_mean), c(50L, 3L))
})

test_that("CovarianceSplit matches its definition when nothing is clipped", {
  set.seed(11)
  for (m in c(2L, 3L, 5L)) {
    curves <- FakeBootCurves(m = m)
    lit <- LiteralSplit(curves, 20L)
    # Precondition: the raw covariance is positive definite, so the
    # eigenvalue clipping changes nothing.
    expect_gt(MinEigen(lit$raw), 0)
    cs <- CovarianceSplit(curves, 20L)
    expect_equal(cs$sigma, lit$raw)
    expect_equal(cs$v, lit$v)
    expect_equal(cs$w, lit$w)
    expect_equal(cs$boot_mean, Reduce(`+`, curves) / m)
  }
})

test_that("CovarianceSplit's W is the preregistered form for M = 2", {
  set.seed(12)
  curves <- FakeBootCurves(m = 2L)
  d <- curves[[1]] - curves[[2]]
  # W = R_B^{-1} sum_b (J_b1 - J_b2)(J_b1 - J_b2)' / 2.
  expect_equal(CovarianceSplit(curves, 20L)$w, crossprod(d) / (2 * nrow(d)))
})

test_that("identical imputations give W = 0 and sigma equal to cov of means", {
  set.seed(13)
  x <- FakeBootCurves(m = 1L)[[1]]
  for (n_imp in c(2L, 20L)) {
    cs <- CovarianceSplit(list(x, x, x), n_imp)
    expect_lt(max(abs(cs$w)), 1e-20)
    expect_equal(cs$v, stats::cov(x))
    # The clipping leaves a positive-definite matrix alone.
    expect_equal(cs$sigma, stats::cov(x))
    expect_equal(cs$boot_mean, x)
  }
})

test_that("a single imputation per resample has W = 0 and sigma = V", {
  set.seed(14)
  x <- FakeBootCurves(m = 1L)[[1]]
  cs <- CovarianceSplit(list(x), 20L)
  expect_equal(max(abs(cs$w)), 0)
  expect_equal(cs$v, stats::cov(x))
  expect_equal(cs$sigma, stats::cov(x))
})

test_that("sigma is symmetric and positive semi-definite, even if clipped", {
  set.seed(15)
  # Few resamples for many points: V is singular and the raw covariance
  # is often indefinite.
  n_clipped <- 0L
  for (i in 1:6) {
    curves <- FakeBootCurves(r_b = 12L, k_n = 8L, m = 2L)
    cs <- CovarianceSplit(curves, 3L)
    raw <- LiteralSplit(curves, 3L)$raw
    n_clipped <- n_clipped + (MinEigen(raw) < -1e-12)
    expect_true(isSymmetric(cs$sigma, tol = 1e-10))
    expect_gte(MinEigen(cs$sigma), -1e-12)
    # V and W themselves come back unclipped.
    expect_equal(cs$v, stats::cov(cs$boot_mean))
  }
  expect_gt(n_clipped, 0L)
})

test_that("a negative semi-definite raw covariance is clipped to zero", {
  set.seed(16)
  r_b <- 300L
  # Resample means do not vary (V = 0), imputations do (W > 0): the raw
  # covariance is W (1/L - 1/2), which is negative.
  e <- 0.3 * matrix(stats::rnorm(2 * r_b), r_b)
  curves <- list(e, -e)
  cs <- CovarianceSplit(curves, 20L)
  expect_lt(max(abs(cs$v)), 1e-20)
  expect_gt(min(diag(cs$w)), 0)
  expect_lt(max(abs(cs$sigma)), 1e-12)
})

test_that("clipping is the nearest positive semi-definite matrix", {
  set.seed(17)
  r_b <- 300L
  # Column 1 varies across resamples, column 2 does not.
  base <- cbind(stats::rnorm(r_b), 0)
  e <- 0.3 * matrix(stats::rnorm(2 * r_b), r_b)
  curves <- list(base + e, base - e)
  cs <- CovarianceSplit(curves, 20L)
  raw <- cs$v - cs$w / 2 + cs$w / 20
  # Precondition: the raw matrix is indefinite.
  expect_lt(MinEigen(raw), 0)
  eig <- eigen(raw, symmetric = TRUE)
  clipped <- eig$vectors %*% diag(pmax(eig$values, 0)) %*% t(eig$vectors)
  expect_equal(cs$sigma, clipped)
  expect_gte(MinEigen(cs$sigma), -1e-12)
})

test_that("CovarianceSplit's diagonal is BootImputeBand's variance split", {
  set.seed(18)
  for (m in c(1L, 2L, 3L)) {
    curves <- FakeBootCurves(m = m)
    cs <- CovarianceSplit(curves, 20L)
    band <- BootImputeBand(curves, estimate = rep(0, 4), n_imp = 20L)
    expect_equal(diag(cs$v), band$v_boot)
    expect_equal(diag(cs$w), band$s_within)
    expect_equal(diag(cs$sigma), band$se^2)
  }
})

test_that("more imputations in the estimate shrink sigma, not V or W", {
  set.seed(19)
  curves <- FakeBootCurves(m = 2L)
  s5 <- CovarianceSplit(curves, 5L)
  s50 <- CovarianceSplit(curves, 50L)
  expect_equal(s5$v, s50$v)
  expect_equal(s5$w, s50$w)
  expect_true(all(diag(s5$sigma) >= diag(s50$sigma) - 1e-12))
  # With L = M the estimate is the resample means: sigma = V.
  expect_equal(CovarianceSplit(curves, 2L)$sigma, s5$v)
})

# -- NormalDraws ----------------------------------------------------------

test_that("NormalDraws returns an n_draw x K matrix", {
  set.seed(30)
  draws <- NormalDraws(RandomSigma(4L), 7L)
  expect_true(is.matrix(draws))
  expect_equal(dim(draws), c(7L, 4L))
  expect_equal(dim(NormalDraws(diag(3), 1L)), c(1L, 3L))
  expect_equal(dim(NormalDraws(matrix(2), 5L)), c(5L, 1L))
})

test_that("NormalDraws has mean zero and the requested covariance", {
  set.seed(31)
  sigma <- matrix(c(1.0, 0.6, -0.3,
                    0.6, 2.0, 0.5,
                    -0.3, 0.5, 0.7), 3, byrow = TRUE)
  draws <- NormalDraws(sigma, 40000L)
  # Monte Carlo error of an entry is about 0.01.
  expect_lt(max(abs(colMeans(draws))), 0.04)
  expect_lt(max(abs(stats::cov(draws) - sigma)), 0.06)
  # One dimension: the standard deviation.
  one <- NormalDraws(matrix(4), 40000L)
  expect_equal(stats::sd(one[, 1]), 2, tolerance = 0.03)
})

test_that("NormalDraws gives zero draws on a zero-variance direction", {
  set.seed(32)
  draws <- NormalDraws(diag(c(1, 0, 2)), 50L)
  expect_lt(max(abs(draws[, 2])), 1e-12)
  expect_gt(stats::sd(draws[, 1]), 0)
  # A negative eigenvalue is treated as zero.
  set.seed(33)
  neg <- NormalDraws(diag(c(1, -1)), 20L)
  set.seed(33)
  zero <- NormalDraws(diag(c(1, 0)), 20L)
  expect_equal(neg, zero)
  expect_lt(max(abs(neg[, 2])), 1e-12)
})

test_that("NormalDraws is reproducible given the seed", {
  sigma <- RandomSigma(3L)
  set.seed(34)
  a <- NormalDraws(sigma, 10L)
  set.seed(34)
  b <- NormalDraws(sigma, 10L)
  expect_identical(a, b)
  expect_false(identical(a, NormalDraws(sigma, 10L)))
})

# -- ComparisonCritical ---------------------------------------------------

test_that("ComparisonCritical matches an explicit double loop", {
  set.seed(40)
  draws <- matrix(stats::rnorm(150 * 6), 150) %*% chol(0.6 * diag(6) + 0.4)
  scale_cov <- stats::cov(draws)
  for (level in c(0.5, 0.9, 0.95)) {
    expect_equal(ComparisonCritical(draws, scale_cov, level),
                 LiteralCritical(draws, scale_cov, level))
  }
  # A different scale matrix, not the draws' own covariance.
  other <- RandomSigma(6L)
  expect_equal(ComparisonCritical(draws, other),
               LiteralCritical(draws, other, 0.95))
})

test_that("ComparisonCritical is the max over k of the level quantiles", {
  set.seed(41)
  draws <- matrix(stats::rnorm(1000 * 5), 1000)
  s <- diag(5)
  q <- ComparisonCritical(draws, s, 0.95)
  frac <- vapply(1:5, function(k) {
    others <- setdiff(1:5, k)
    z <- (draws[, others] - draws[, k]) / sqrt(2)
    mean(apply(z, 1, max) <= q)
  }, numeric(1))
  # At least 95% of draws satisfy every comparison for each k, and the
  # binding k meets it as tightly as a quantile can.
  expect_true(all(frac >= 0.95 - 1e-9))
  expect_lt(min(frac), 0.953)
})

test_that("ComparisonCritical is about qnorm(0.95) for two independent draws", {
  set.seed(42)
  draws <- matrix(stats::rnorm(40000 * 2), 40000)
  expect_equal(ComparisonCritical(draws, diag(2)), stats::qnorm(0.95),
               tolerance = 0.03)
})

test_that("ComparisonCritical grows with the number of independent points", {
  set.seed(43)
  draws <- matrix(stats::rnorm(4000 * 40), 4000)
  q <- vapply(c(2L, 5L, 10L, 20L, 40L), function(k_n) {
    ComparisonCritical(draws[, seq_len(k_n)], diag(k_n))
  }, numeric(1))
  expect_true(all(diff(q) > 0))
  expect_gt(q[5], q[1] + 0.8)
})

test_that("ComparisonCritical rises with the level", {
  set.seed(44)
  draws <- matrix(stats::rnorm(2000 * 6), 2000)
  q <- vapply(c(0.5, 0.8, 0.95, 0.99), function(level) {
    ComparisonCritical(draws, diag(6), level)
  }, numeric(1))
  expect_true(all(diff(q) > 0))
})

test_that("ComparisonCritical scales inversely with the scale matrix", {
  set.seed(45)
  draws <- matrix(stats::rnorm(500 * 4), 500)
  s <- RandomSigma(4L)
  base <- ComparisonCritical(draws, s)
  # Standard errors double, so the standardized differences halve.
  expect_equal(ComparisonCritical(draws, 4 * s), base / 2)
  # A common shift of every coordinate of a draw leaves differences alone.
  shifted <- draws + stats::rnorm(500)
  expect_equal(ComparisonCritical(shifted, s), base)
})

test_that("ComparisonCritical leaves out pairs with zero variance", {
  set.seed(46)
  # Coordinate 3 is a copy of coordinate 1: s_13 = 0 exactly.
  s3 <- matrix(c(1.0, 0.3, 1.0,
                 0.3, 1.0, 0.3,
                 1.0, 0.3, 1.0), 3, byrow = TRUE)
  base <- matrix(stats::rnorm(300 * 2), 300)
  draws <- cbind(base, base[, 1])
  q <- ComparisonCritical(draws, s3)
  expect_true(is.finite(q))
  # The copy adds no comparison: the same critical value as two points.
  expect_equal(q, ComparisonCritical(base, s3[1:2, 1:2]))
  expect_equal(q, LiteralCritical(draws, s3, 0.95))
})

test_that("ComparisonCritical is -Inf when no pair has positive variance", {
  set.seed(47)
  draws <- matrix(stats::rnorm(50 * 3), 50)
  expect_identical(ComparisonCritical(draws, matrix(0, 3, 3)), -Inf)
  expect_identical(ComparisonCritical(draws[, 1, drop = FALSE], matrix(1)),
                   -Inf)
})

# -- Tied grid points (issue C1 of the background report) -----------------

test_that("PairSe sets the rounding error of a tied pair to zero", {
  set.seed(60)
  sigma <- TiedSplit()$sigma
  # Precondition: the eigenvalue reconstruction leaves the tied pairs a
  # rounding error, a positive variance far below the tolerance of 1e-10.
  raw <- PairSe(sigma, 1L, tol = 0)
  expect_gt(raw[2], 0)
  expect_lt(max(raw[2:3]^2), 1e-12 * max(diag(sigma)))
  s <- PairSe(sigma, 1L)
  expect_identical(s[1:3], c(0, 0, 0))
  # Genuine differences are untouched and match the formula.
  d <- diag(sigma)
  expect_identical(s[4:6], raw[4:6])
  expect_equal(s[4:6], sqrt(d[4:6] + d[1] - 2 * sigma[4:6, 1]))
})

test_that("PairSe with tol = 0 is the formula with negatives set to zero", {
  set.seed(61)
  sigma <- RandomSigma(7L)
  d <- diag(sigma)
  for (k in c(1L, 4L, 7L)) {
    expect_equal(PairSe(sigma, k, tol = 0),
                 sqrt(pmax(d + d[k] - 2 * sigma[, k], 0)))
  }
  expect_identical(PairSe(sigma, 3L)[3], 0)
})

test_that("tied grid points add no comparison to the per-point quantiles", {
  set.seed(62)
  sigma <- TiedSplit()$sigma
  draws <- NormalDraws(sigma, 4000L)
  q <- ComparisonQuantiles(draws, sigma)
  # Known answer: each tied point is compared with the three untied points
  # only, so its quantile is that of the four-point problem; the untied
  # points see one copy of the tied curve or three, with the same maximum.
  one <- c(1L, 4L, 5L, 6L)
  for (k in 1:3) {
    keep <- c(k, 4L, 5L, 6L)
    expect_equal(q[k], ComparisonQuantiles(draws[, keep],
                                           sigma[keep, keep])[1])
  }
  expect_equal(q[4:6], ComparisonQuantiles(draws[, one],
                                           sigma[one, one])[2:4])
  expect_equal(max(q), ComparisonCritical(draws, sigma))
})

test_that("tied grid points share their membership of the set", {
  set.seed(63)
  sigma <- TiedSplit()$sigma
  estimate <- c(rep(0.40, 3), 0.43, 0.41, 0.30)
  one <- c(1L, 4L, 5L, 6L)
  for (q in c(0, 0.5, 1.645, 3)) {
    reduced <- ComparisonSet(estimate[one], sigma[one, one], q)
    expect_identical(ComparisonSet(estimate, sigma, q),
                     c(rep(reduced[1], 3), reduced[2:4]))
  }
})

test_that("SupTCritical leaves out a coordinate with rounding-error variance", {
  set.seed(64)
  a <- SupTCritical(diag(c(1, 1e-20, 1)), 0.95, 3000)
  set.seed(64)
  b <- SupTCritical(diag(2), 0.95, 3000)
  expect_identical(a, b)
  # With tol = 0 the coordinate stays in and takes its own draws.
  set.seed(64)
  expect_false(identical(SupTCritical(diag(c(1, 1e-20, 1)), 0.95, 3000,
                                      tol = 0), b))
})

# -- ComparisonSet --------------------------------------------------------

test_that("ComparisonSet matches an explicit double loop", {
  set.seed(50)
  for (i in 1:6) {
    estimate <- stats::rnorm(8)
    sigma <- RandomSigma(8L)
    for (q in c(0, 0.5, 1.645, 3)) {
      out <- ComparisonSet(estimate, sigma, q)
      expect_type(out, "logical")
      expect_length(out, 8L)
      expect_identical(out, LiteralSet(estimate, sigma, q))
    }
  }
})

test_that("the grid's best estimate is always in the set", {
  set.seed(51)
  for (i in 1:20) {
    k_n <- sample(2:12, 1)
    estimate <- stats::rnorm(k_n)
    sigma <- RandomSigma(k_n)
    for (q in c(0, 0.01, 1, 2.5, 10)) {
      expect_true(ComparisonSet(estimate, sigma, q)[which.max(estimate)])
    }
  }
})

test_that("a larger critical value gives a superset", {
  set.seed(52)
  estimate <- stats::rnorm(15)
  sigma <- RandomSigma(15L)
  qs <- c(0, 0.5, 1, 1.645, 2.5, 4)
  sets <- lapply(qs, function(q) ComparisonSet(estimate, sigma, q))
  for (i in 2:length(qs)) {
    expect_true(all(sets[[i]][sets[[i - 1]]]))
    expect_gte(sum(sets[[i]]), sum(sets[[i - 1]]))
  }
  # Larger standard errors do the same.
  expect_true(all(ComparisonSet(estimate, 4 * sigma, 1.645)[
    ComparisonSet(estimate, sigma, 1.645)]))
})

test_that("with a huge critical value every point is in the set", {
  set.seed(53)
  estimate <- stats::rnorm(10)
  sigma <- RandomSigma(10L)
  expect_true(all(ComparisonSet(estimate, sigma, 1e6)))
})

test_that("with q = 0 only the ties of the maximum are in the set", {
  sigma <- diag(4)
  expect_identical(ComparisonSet(c(1, 3, 3, 2), sigma, 0),
                   c(FALSE, TRUE, TRUE, FALSE))
  expect_identical(ComparisonSet(c(0.2, 0.9, 0.5, 0.1), sigma, 0),
                   c(FALSE, TRUE, FALSE, FALSE))
  # All equal: every point is a tie.
  expect_true(all(ComparisonSet(rep(0.5, 4), sigma, 0)))
})

test_that("ComparisonSet standardizes by the difference's standard error", {
  # Two points, estimates 0 and 1, difference variance 1 + 1 - 2 * 0.5 = 1:
  # point 1 is out iff 1 > q.
  sigma <- matrix(c(1, 0.5, 0.5, 1), 2)
  expect_identical(ComparisonSet(c(0, 1), sigma, 0.9), c(FALSE, TRUE))
  expect_identical(ComparisonSet(c(0, 1), sigma, 1.1), c(TRUE, TRUE))
  # Perfect correlation: the difference has no error, so any positive gap
  # excludes the lower point whatever q is.
  tight <- matrix(1, 2, 2)
  expect_identical(ComparisonSet(c(1, 2), tight, 1e6), c(FALSE, TRUE))
})

test_that("ComparisonSet ignores a common shift of the estimate", {
  set.seed(54)
  estimate <- stats::rnorm(9)
  sigma <- RandomSigma(9L)
  expect_identical(ComparisonSet(estimate + 5, sigma, 1.645),
                   ComparisonSet(estimate, sigma, 1.645))
  # One point is trivially in its own set.
  expect_true(ComparisonSet(0.3, matrix(1), 2))
})

# -- SetOnGrid ------------------------------------------------------------

test_that("SetOnGrid's length is the points in the set times the step", {
  grid <- seq(0, 2, length.out = 5)
  out <- SetOnGrid(grid, c(FALSE, TRUE, TRUE, TRUE, FALSE), 2L)
  expect_named(out, c("length", "contains"))
  expect_equal(out$length, 3 * 0.5)
  expect_true(out$contains)
  expect_false(SetOnGrid(grid, c(FALSE, TRUE, TRUE, TRUE, FALSE), 5L)$contains)
  expect_equal(SetOnGrid(grid, rep(FALSE, 5), 3L)$length, 0)
  expect_equal(SetOnGrid(grid, rep(TRUE, 5), 3L)$length, 5 * 0.5)
})

test_that("SetOnGrid's contains is the set's value at the target point", {
  set.seed(60)
  grid <- seq(-1.3, 2.7, length.out = 41)
  for (i in 1:10) {
    in_set <- stats::runif(41) < 0.4
    k_best <- sample(41, 1)
    out <- SetOnGrid(grid, in_set, k_best)
    expect_identical(unname(out$contains), in_set[k_best])
    expect_equal(out$length, sum(in_set) * (4 / 40))
  }
})

test_that("SetOnGrid has step zero on a one-point grid", {
  out <- SetOnGrid(1.5, TRUE, 1L)
  expect_equal(out$length, 0)
  expect_true(out$contains)
})

# -- TrueNearRegionLength -------------------------------------------------

# The region {c : J(c) >= J* - tol} found by counting points on a fine grid.
GridRegion <- function(delta, sigma1, tol, step = 1e-4) {
  truth <- MarkerTruth(delta, sigma1)
  cc <- seq(-6, 14, by = step)
  inside <- TrueYouden(cc, delta, sigma1) >= truth$j_star - tol
  list(length = sum(inside) * step, lo = min(cc[inside]),
       hi = max(cc[inside]), n_inside = sum(inside), step = step,
       c_star = truth$c_star)
}

# The two crossing points by a separate root-finding.
SeparateRoots <- function(delta, sigma1, tol) {
  truth <- MarkerTruth(delta, sigma1)
  f <- function(cc) TrueYouden(cc, delta, sigma1) - (truth$j_star - tol)
  lo <- stats::uniroot(f, c(-6, truth$c_star), tol = 1e-12)$root
  hi <- stats::uniroot(f, c(truth$c_star, delta + 8 * sigma1),
                       tol = 1e-12)$root
  c(lo = lo, hi = hi)
}

test_that("TrueNearRegionLength equals a separate root-finding (sharp)", {
  for (tol in c(0.002, 0.01, 0.03)) {
    roots <- SeparateRoots(2, 1, tol)
    expect_equal(TrueNearRegionLength(2, 1, tol),
                 unname(roots[["hi"]] - roots[["lo"]]), tolerance = 1e-7)
  }
  expect_equal(TrueNearRegionLength(2, 1), TrueNearRegionLength(2, 1, 0.01))
})

test_that("TrueNearRegionLength agrees with counting points on a fine grid", {
  for (shape in list(c(2, 1), c(1.5, 2.5))) {
    reg <- GridRegion(shape[1], shape[2], 0.01)
    expect_lt(abs(TrueNearRegionLength(shape[1], shape[2]) - reg$length),
              5e-4)
    # One interval around c*, with every grid point between its ends.
    expect_lt(reg$lo, reg$c_star)
    expect_gt(reg$hi, reg$c_star)
    expect_equal(reg$n_inside, round((reg$hi - reg$lo) / reg$step) + 1)
  }
})

test_that("the flat shape's crossing points bracket c*", {
  truth <- MarkerTruth(1.5, 2.5)
  roots <- SeparateRoots(1.5, 2.5, 0.01)
  expect_lt(roots[["lo"]], truth$c_star)
  expect_gt(roots[["hi"]], truth$c_star)
  expect_equal(TrueNearRegionLength(1.5, 2.5),
               unname(roots[["hi"]] - roots[["lo"]]), tolerance = 1e-7)
  # The flatter curve has the longer near-optimal region.
  expect_gt(TrueNearRegionLength(1.5, 2.5), TrueNearRegionLength(2, 1))
})

test_that("TrueNearRegionLength increases with the tolerance", {
  tols <- c(0.001, 0.005, 0.01, 0.02, 0.05)
  for (shape in list(c(2, 1), c(1.5, 2.5))) {
    len <- vapply(tols, function(tol) {
      TrueNearRegionLength(shape[1], shape[2], tol)
    }, numeric(1))
    expect_true(all(diff(len) > 0))
    expect_true(all(len > 0))
  }
})

test_that("TrueNearRegionLength is quadratic-width for a small tolerance", {
  truth <- MarkerTruth(2, 1)
  tol <- 1e-6
  # J(c) is about J* - kappa (c - c*)^2 / 2 near the maximum.
  expect_equal(TrueNearRegionLength(2, 1, tol),
               2 * sqrt(2 * tol / truth$kappa), tolerance = 0.02)
})
