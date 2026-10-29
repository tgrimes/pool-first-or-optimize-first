test_that("EducationIncome maps the codebook codes", {
  demo <- data.frame(SEQN = 1:8, DMDEDUC2 = c(1, 2, 3, 4, 5, 7, 9, NA),
                     INDFMPIR = c(0.5, 1, 1.99, 2, 3.99, 4, 5, NA))
  out <- EducationIncome(demo)
  expect_equal(out$educ, c(rep("less than high school", 2), "high school",
                           "some college", "college graduate",
                           rep("unknown", 3)))
  expect_equal(out$income, c("below 1", "1 to 2", "1 to 2", "2 to 4",
                             "2 to 4", "4 or more", "4 or more", "unknown"))
})

FakeCohort <- function(n = 60) {
  set.seed(11)
  data.frame(smoker = rep(0:1, length.out = n), age = 20 + (seq_len(n) %% 60),
             sex = rep(c("male", "female"), each = n / 2),
             race = rep(c("a", "b", "c"), length.out = n),
             cycle = rep(c("x", "y"), each = n / 2),
             educ = "some college", income = rep(c("u", "v"), n / 2),
             stringsAsFactors = FALSE)
}

test_that("CotininePredictors builds indicators and drops a factor", {
  co <- FakeCohort()
  p <- CotininePredictors(co)
  # d, age, age2, male, d_age, d_male; race 2; cycle 1; educ none; income 1
  expect_equal(ncol(p), 6 + 2 + 1 + 1)
  expect_equal(p[, "d"], co$smoker)
  expect_equal(p[, "race_1"], as.numeric(co$race == "b"))
  p2 <- CotininePredictors(co, drop = "race")
  expect_false(any(grepl("^race", colnames(p2))))
})

test_that("ImputePmmMatrix keeps observed values and copies complete data", {
  co <- FakeCohort()
  p <- CotininePredictors(co)
  set.seed(12)
  x <- stats::rnorm(60) + co$smoker
  x_miss <- x
  x_miss[c(3, 10, 20)] <- NA
  comp <- ImputePmmMatrix(x_miss, p, 4)
  expect_equal(dim(comp), c(60, 4))
  expect_equal(comp[-c(3, 10, 20), 2], x[-c(3, 10, 20)])
  expect_true(all(comp[c(3, 10, 20), ] %in% x[-c(3, 10, 20)]))
  expect_equal(ImputePmmMatrix(x, p, 3), matrix(x, 60, 3))
})

test_that("ImposeMissing hits its target fraction", {
  n <- 50000
  co <- data.frame(smoker = rbinom(n, 1, 0.2), age = runif(n, 18, 80),
                   sex = sample(c("male", "female"), n, TRUE))
  set.seed(13)
  expect_lt(abs(mean(ImposeMissing(co, 0.4)) - 0.4), 0.01)
})

test_that("StratumCutoffs: equal shares give the stratum's own cutoff", {
  set.seed(14)
  d <- rep(0:1, each = 200)
  x <- c(stats::rnorm(200), stats::rnorm(200, 2))
  comp <- cbind(x, x)
  same <- StratumCutoffs(comp, d, w0 = 0.3, w1 = 0.3)
  expect_equal(same$c_pop, same$c_cs)
  emp <- EmpiricalCurves(comp, d)
  expect_equal(same$c_cs, MaximizeStep(emp$u, emp$values[1, ])$cutoff)
  # A stratum holding more of the controls than of the cases weighs
  # specificity more, so its population-optimal cutoff is not lower.
  more0 <- StratumCutoffs(comp, d, w0 = 0.5, w1 = 0.1)
  expect_gte(more0$c_pop, same$c_cs)
})

test_that("RunApplicationTask is reproducible and SummarizeAnalysis reads it", {
  co <- FakeCohort(80)
  set.seed(15)
  x <- stats::rnorm(80) + 2 * co$smoker
  x[seq(5, 80, by = 9)] <- NA
  task <- list(name = "t", seed = 3L, x = x, d = co$smoker,
               predictors = CotininePredictors(co), n_imp = 3L,
               n_boot = 20L, m_boot = 2L, n_boot_opt = 5L, n_boot_opt2 = 5L,
               grid_n = 9L, n_draw = 500L)
  kind <- RNGkind()
  on.exit(RNGkind(kind[1], kind[2], kind[3]))
  a <- RunApplicationTask(task)
  b <- RunApplicationTask(task)
  expect_equal(a$estimate, b$estimate)
  expect_equal(a$corrected_20, b$corrected_20)
  s <- SummarizeAnalysis(a, reference = 0.5)
  expect_length(s$grid, 9)
  expect_named(s$reference_in_sets[[1]],
               c("comp_boot", "comp_hybrid", "plug_boot", "plug_hybrid",
                 "band_boot", "band_hybrid"))
  expect_equal(s$c_hat, a$c_hat)
})

test_that("ImputePmmMatrix drops collinear predictors", {
  co <- FakeCohort()
  p <- CotininePredictors(co)
  p <- cbind(p, twin = p[, "age"] * 2)
  set.seed(16)
  x <- stats::rnorm(60)
  x[c(1, 2)] <- NA
  expect_no_error(ImputePmmMatrix(x, p, 2))
})
