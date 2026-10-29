# Tests for R/impute.R: the PMM and nearest-neighbour imputation engines and
# the donor search.

# A small MAR dataset with continuous (so distinct) marker values.
MakeMissingData <- function(n = 40, rate = 0.4, seed = 1) {
  set.seed(seed)
  alpha0 <- MissingIntercept(rate, 2, 1)
  SimulateMarkerData(n, 2, 1, alpha0)
}

# Properties every engine must satisfy.
ExpectValidImputation <- function(completed, dat, n_imp) {
  expect_true(is.matrix(completed))
  expect_equal(dim(completed), c(nrow(dat), n_imp))
  expect_false(anyNA(completed))
  for (l in seq_len(n_imp)) {
    # Observed rows are unchanged in every column.
    expect_identical(completed[dat$observed, l], dat$x[dat$observed])
    # Every imputed value is one of the observed values.
    imputed <- completed[!dat$observed, l]
    expect_true(all(imputed %in% dat$x[dat$observed]))
  }
}

test_that("ImputePmm returns an N x L matrix that only fills the gaps", {
  dat <- MakeMissingData()
  expect_gt(sum(!dat$observed), 5)
  set.seed(11)
  completed <- ImputePmm(dat$x, dat$d, dat$z, n_imp = 4)
  ExpectValidImputation(completed, dat, 4)
})

test_that("ImputePmm imputations differ across columns", {
  dat <- MakeMissingData(n = 60, seed = 2)
  set.seed(12)
  completed <- ImputePmm(dat$x, dat$d, dat$z, n_imp = 6)
  ExpectValidImputation(completed, dat, 6)
  gaps <- completed[!dat$observed, , drop = FALSE]
  # With 5 donors and many missing rows, the columns cannot all agree.
  expect_gt(length(unique(apply(gaps, 2, paste, collapse = ","))), 1)
})

test_that("ImputePmm accepts other donor counts", {
  dat <- MakeMissingData(n = 60, seed = 3)
  set.seed(13)
  for (donors in c(1L, 3L, 10L)) {
    completed <- ImputePmm(dat$x, dat$d, dat$z, n_imp = 3, donors = donors)
    ExpectValidImputation(completed, dat, 3)
  }
})

test_that("ImputePmm imputes close to the truth on average (MAR through Z)", {
  dat <- MakeMissingData(n = 400, seed = 4)
  set.seed(14)
  completed <- ImputePmm(dat$x, dat$d, dat$z, n_imp = 5)
  miss <- !dat$observed
  err <- completed[miss, ] - dat$x_full[miss]
  # Z = X + N(0, 1) is informative, so the imputed values track the truth.
  expect_gt(cor(rowMeans(completed[miss, ]), dat$x_full[miss]), 0.4)
  expect_lt(abs(mean(err)), 0.5)
})

test_that("NearestDonors returns same-group observed donors, k per column", {
  set.seed(21)
  n <- 30
  d <- rep(c(0L, 1L), each = n)
  observed <- runif(2 * n) > 0.4
  s1 <- rnorm(2 * n)
  s2 <- rnorm(2 * n)
  k <- 3L
  donors <- NearestDonors(s1, s2, observed, d, k = k)
  miss_idx <- which(!observed)
  expect_equal(dim(donors), c(k, length(miss_idx)))
  expect_false(anyNA(donors))
  for (j in seq_along(miss_idx)) {
    expect_true(all(observed[donors[, j]]))
    expect_true(all(d[donors[, j]] == d[miss_idx[j]]))
    expect_equal(anyDuplicated(donors[, j]), 0L)
  }
})

test_that("NearestDonors with s2 = s1 is the k nearest in |s1| (loop)", {
  set.seed(22)
  n <- 25
  d <- rep(c(0L, 1L), each = n)
  observed <- runif(2 * n) > 0.35
  s1 <- rnorm(2 * n)
  k <- 4L
  donors <- NearestDonors(s1, s1, observed, d, k = k)
  miss_idx <- which(!observed)
  for (j in seq_along(miss_idx)) {
    i <- miss_idx[j]
    cand <- integer(0)
    dist <- numeric(0)
    for (m in seq_along(observed)) {
      if (observed[m] && d[m] == d[i]) {
        cand <- c(cand, m)
        dist <- c(dist, abs(s1[i] - s1[m]))
      }
    }
    expected <- cand[order(dist)][seq_len(k)]
    expect_identical(donors[, j], expected)
  }
})

test_that("NearestDonors honours the weights on the two scores", {
  set.seed(23)
  n <- 20
  d <- rep(c(0L, 1L), each = n)
  observed <- runif(2 * n) > 0.35
  s1 <- rnorm(2 * n)
  s2 <- rnorm(2 * n)
  w <- c(0.8, 0.2)
  k <- 3L
  donors <- NearestDonors(s1, s2, observed, d, k = k, weights = w)
  miss_idx <- which(!observed)
  for (j in seq_along(miss_idx)) {
    i <- miss_idx[j]
    cand <- which(observed & d == d[i])
    dist <- sqrt(w[1] * (s1[i] - s1[cand])^2 + w[2] * (s2[i] - s2[cand])^2)
    expect_identical(donors[, j], cand[order(dist)][seq_len(k)])
  }
  # Putting all the weight on s2 ignores s1 completely.
  only2 <- NearestDonors(s1, s2, observed, d, k = k, weights = c(0, 1))
  shuffled <- NearestDonors(sample(s1), s2, observed, d, k = k,
                            weights = c(0, 1))
  expect_identical(only2, shuffled)
})

test_that("NearestDonors handles a single missing subject and k = 1", {
  d <- c(0L, 0L, 0L, 1L, 1L)
  observed <- c(TRUE, TRUE, FALSE, TRUE, TRUE)
  s1 <- c(0.1, 0.9, 0.2, 0.15, 0.25)
  donors <- NearestDonors(s1, s1, observed, d, k = 1L)
  expect_equal(dim(donors), c(1L, 1L))
  expect_equal(donors[1, 1], 1L)
})

test_that("ImputeNearestNeighbour fills the gaps from same-group donors", {
  dat <- MakeMissingData(n = 40, seed = 5)
  set.seed(31)
  completed <- ImputeNearestNeighbour(dat$x, dat$d, dat$z, n_imp = 5)
  ExpectValidImputation(completed, dat, 5)
  # Group d draws only from observed values of group d.
  for (g in 0:1) {
    rows <- which(!dat$observed & dat$d == g)
    pool <- dat$x[dat$observed & dat$d == g]
    expect_true(all(completed[rows, ] %in% pool))
  }
})

test_that("ImputeNearestNeighbour works without the bootstrap step", {
  dat <- MakeMissingData(n = 40, seed = 6)
  set.seed(32)
  completed <- ImputeNearestNeighbour(dat$x, dat$d, dat$z, n_imp = 3,
                                      bootstrap = FALSE)
  ExpectValidImputation(completed, dat, 3)
})

test_that("with k = 1 and no bootstrap every imputation is identical", {
  dat <- MakeMissingData(n = 40, seed = 7)
  set.seed(33)
  completed <- ImputeNearestNeighbour(dat$x, dat$d, dat$z, n_imp = 4, k = 1L,
                                      bootstrap = FALSE)
  ExpectValidImputation(completed, dat, 4)
  for (l in 2:4) expect_identical(completed[, l], completed[, 1])
})

test_that("the nearest-neighbour donor is the nearest on the fitted scores", {
  dat <- MakeMissingData(n = 40, seed = 8)
  set.seed(34)
  completed <- ImputeNearestNeighbour(dat$x, dat$d, dat$z, n_imp = 1, k = 1L,
                                      bootstrap = FALSE, weights = c(1, 0))
  # With all the weight on the prediction score, the donor is the observed
  # subject of the same group with the closest fitted marker value.
  fit <- lm(x ~ d * z, data = dat, subset = observed)
  s1 <- as.vector(scale(predict(fit, newdata = dat)))
  miss_idx <- which(!dat$observed)
  for (i in miss_idx) {
    cand <- which(dat$observed & dat$d == dat$d[i])
    nearest <- cand[which.min(abs(s1[i] - s1[cand]))]
    expect_equal(completed[i, 1], dat$x[nearest])
  }
})

test_that("both engines return the data unchanged when nothing is missing", {
  set.seed(41)
  dat <- SimulateMarkerData(20, 2, 1)
  nn <- ImputeNearestNeighbour(dat$x, dat$d, dat$z, n_imp = 3)
  expect_equal(dim(nn), c(40L, 3L))
  for (l in 1:3) expect_identical(nn[, l], dat$x)
})

test_that("imputation is reproducible under a seed", {
  dat <- MakeMissingData(n = 40, seed = 9)
  set.seed(51)
  a <- ImputePmm(dat$x, dat$d, dat$z, 3)
  set.seed(51)
  b <- ImputePmm(dat$x, dat$d, dat$z, 3)
  expect_identical(a, b)
  set.seed(52)
  a <- ImputeNearestNeighbour(dat$x, dat$d, dat$z, 3)
  set.seed(52)
  b <- ImputeNearestNeighbour(dat$x, dat$d, dat$z, 3)
  expect_identical(a, b)
})
