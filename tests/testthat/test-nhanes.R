# Tests for R/nhanes.R: the NHANES file list, the cohort builder, the real
# marker's Youden curve, and the file reader.

test_that("NhanesFiles lists 9 files with the CDC URL pattern", {
  files <- NhanesFiles()
  expect_equal(nrow(files), 9L)
  expect_true(all(c("cycle", "year", "suffix", "component", "file", "url")
                  %in% names(files)))
  expect_setequal(files$cycle, c("2013-2014", "2015-2016", "2017-2018"))
  expect_setequal(files$component, c("COT", "SMQ", "DEMO"))
  expect_true(all(grepl(
    paste0("^https://wwwn\\.cdc\\.gov/Nchs/Data/Nhanes/Public/",
           "(2013|2015|2017)/DataFiles/(COT|SMQ|DEMO)_(H|I|J)\\.xpt$"),
    files$url)))
  coj <- paste0("https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/",
                "DataFiles/COT_J.xpt")
  expect_true(coj %in% files$url)
  expect_equal(basename(files$url), files$file)
  expect_equal(files$file, paste0(files$component, "_", files$suffix, ".xpt"))
  expect_equal(anyDuplicated(files$url), 0L)
})

test_that("NhanesFiles pairs each cycle with its folder year and suffix", {
  files <- NhanesFiles()
  expect_equal(files$suffix[files$cycle == "2013-2014"], rep("H", 3))
  expect_equal(files$suffix[files$cycle == "2015-2016"], rep("I", 3))
  expect_equal(files$suffix[files$cycle == "2017-2018"], rep("J", 3))
  expect_equal(files$year[files$cycle == "2015-2016"], rep(2015L, 3))
  for (i in seq_len(nrow(files))) {
    expect_true(grepl(sprintf("/%d/DataFiles/", files$year[i]),
                      files$url[i], fixed = TRUE))
  }
  # Sorted by year, then component.
  expect_false(is.unsorted(files$year))
})

# Tiny hand-made cot, smq and demo frames for BuildCotinineCohort().
#   1  never smoked 100 cigarettes                        -> nonsmoker
#   2  smoked 100, now every day (SMQ040 1)               -> smoker
#   3  smoked 100, now some days (SMQ040 2)               -> smoker
#   4  smoked 100, now not at all (SMQ040 3)              -> nonsmoker
#   5  smoked 100, SMQ040 missing                         -> dropped
#   6  age 17                                             -> dropped
#   7  SMQ020 = 7 (refused)                               -> dropped
#   8  SMQ020 = 9 (don't know)                            -> dropped
#   9  nonsmoker with no cotinine measurement             -> kept, NA
#  10  SMQ020 = 1, SMQ040 = 7 (refused)                   -> dropped
#  11  age missing                                        -> dropped
#  12  nonsmoker below the detection limit                -> kept
MakeNhanesFrames <- function() {
  seqn <- 1:12
  demo <- data.frame(
    SEQN = seqn,
    RIDAGEYR = c(30, 45, 52, 61, 40, 17, 33, 29, 71, 38, NA, 25),
    RIAGENDR = c(1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2),
    RIDRETH3 = c(1, 2, 3, 4, 6, 7, 3, 3, 4, 1, 2, 6),
    RIDSTATR = c(2, 2, 2, 2, 2, 1, 2, 2, 2, 2, 2, 2))
  smq <- data.frame(
    SEQN = seqn,
    SMQ020 = c(2, 1, 1, 1, 1, 2, 7, 9, 2, 1, 2, 2),
    SMQ040 = c(NA, 1, 2, 3, NA, NA, NA, NA, NA, 7, NA, NA))
  cot <- data.frame(
    SEQN = setdiff(seqn, 9),
    LBXCOT = c(0.02, 150, 40, 0.5, 0.3, 0.01, 0.2, 0.1, 0.05, 0.3, 0.011),
    LBDCOTLC = c(0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1))
  list(cot = cot, smq = smq, demo = demo)
}

test_that("BuildCotinineCohort classifies smokers and drops the unusable", {
  f <- MakeNhanesFrames()
  out <- BuildCotinineCohort(f$cot, f$smq, f$demo, "2017-2018")
  expect_s3_class(out, "data.frame")
  expect_named(out, c("seqn", "cycle", "age", "sex", "race", "examined",
                      "cotinine", "below_lod", "smoker"))
  # Kept: 1, 2, 3, 4, 9, 12.
  expect_equal(out$seqn, c(1, 2, 3, 4, 9, 12))
  expect_equal(out$smoker, c(0L, 1L, 1L, 0L, 0L, 0L))
  expect_true(all(out$cycle == "2017-2018"))
  expect_true(all(out$age >= 18))
  expect_false(anyNA(out$smoker))
})

test_that("BuildCotinineCohort maps the demographic and lab columns", {
  f <- MakeNhanesFrames()
  out <- BuildCotinineCohort(f$cot, f$smq, f$demo, "2017-2018")
  expect_equal(out$sex, c("male", "female", "male", "female", "male",
                          "female"))
  expect_equal(out$race, c("Mexican American", "Other Hispanic",
                           "Non-Hispanic White", "Non-Hispanic Black",
                           "Non-Hispanic Black", "Non-Hispanic Asian"))
  expect_equal(out$age, c(30, 45, 52, 61, 71, 25))
  expect_true(all(out$examined))
  # Cotinine is carried through; the subject without a measurement is NA.
  expect_equal(out$cotinine, c(0.02, 150, 40, 0.5, NA, 0.011))
  expect_equal(out$below_lod, c(FALSE, FALSE, FALSE, FALSE, FALSE, TRUE))
})

test_that("BuildCotinineCohort keeps missing cotinine and non-examined", {
  f <- MakeNhanesFrames()
  f$demo$RIDSTATR[1] <- 1
  out <- BuildCotinineCohort(f$cot, f$smq, f$demo, "x")
  expect_false(out$examined[out$seqn == 1])
  expect_true(is.na(out$cotinine[out$seqn == 9]))
  expect_equal(nrow(out), 6L)
})

test_that("BuildCotinineCohort drops everyone who is under 18 or unknown", {
  f <- MakeNhanesFrames()
  out <- BuildCotinineCohort(f$cot, f$smq, f$demo, "x")
  expect_false(any(c(6, 11) %in% out$seqn))
  # Refused or don't-know on the 100-cigarette question.
  expect_false(any(c(7, 8) %in% out$seqn))
  # A smoker with a refused current-smoking answer.
  expect_false(10 %in% out$seqn)
  # SMQ040 missing among those who smoked 100 cigarettes.
  expect_false(5 %in% out$seqn)
})

test_that("BuildCotinineCohort only needs participants in demo and smq", {
  f <- MakeNhanesFrames()
  f$cot <- f$cot[f$cot$SEQN %in% c(1, 2), ]
  out <- BuildCotinineCohort(f$cot, f$smq, f$demo, "x")
  expect_equal(out$seqn, c(1, 2, 3, 4, 9, 12))
  expect_equal(sum(is.na(out$cotinine)), 4L)
  # A cot row for someone outside demo and smq is ignored.
  f$cot <- rbind(f$cot, data.frame(SEQN = 99, LBXCOT = 5, LBDCOTLC = 0))
  out2 <- BuildCotinineCohort(f$cot, f$smq, f$demo, "x")
  expect_false(99 %in% out2$seqn)
})

test_that("RealYoudenCurve recovers a binormal marker's optimum", {
  set.seed(1)
  n <- 2000
  d <- rep(0:1, each = n)
  x <- c(rnorm(n), rnorm(n, 2, 1))
  out <- RealYoudenCurve(x, d)
  # Absolute tolerances: the sampling error of the kernel curvature at
  # n = 2000 per group is about 0.1.
  expect_lt(abs(out$c_star - 1), 0.15)
  expect_lt(abs(out$kappa - 2 * dnorm(1)), 0.2)
  expect_lt(abs(out$j_star - (2 * pnorm(1) - 1)), 0.05)
  expect_lt(abs(out$c_star_empirical - 1), 0.3)
  expect_lt(abs(out$j_star_empirical - (2 * pnorm(1) - 1)), 0.05)
})

test_that("RealYoudenCurve standardizes by group 0 and returns grid curves", {
  set.seed(2)
  n <- 500
  d <- rep(0:1, each = n)
  x <- c(rnorm(n, 3, 2), rnorm(n, 7, 2))
  out <- RealYoudenCurve(x, d, grid_n = 101L)
  expect_named(out, c("center", "scale", "grid", "empirical", "kernel",
                      "c_star", "j_star", "kappa", "c_star_empirical",
                      "j_star_empirical"))
  expect_equal(out$center, mean(x[d == 0]))
  expect_equal(out$scale, sd(x[d == 0]))
  expect_length(out$grid, 101L)
  expect_length(out$empirical, 101L)
  expect_length(out$kernel, 101L)
  expect_false(is.unsorted(out$grid))
  xs <- (x - out$center) / out$scale
  expect_equal(out$grid[1], unname(quantile(xs, 0.005)))
  expect_equal(out$grid[101], unname(quantile(xs, 0.995)))
  # The maximum is attained inside the grid and is at least the grid's.
  expect_gte(out$j_star, max(out$kernel) - 1e-12)
  expect_gt(out$c_star, out$grid[1])
  expect_lt(out$c_star, out$grid[101])
  expect_gt(out$kappa, 0)
  # Smooth and empirical curves agree closely for this much data.
  expect_lt(max(abs(out$empirical - out$kernel)), 0.08)
})

test_that("RealYoudenCurve's standardized answers ignore location and scale", {
  set.seed(3)
  n <- 400
  d <- rep(0:1, each = n)
  x <- c(rnorm(n), rnorm(n, 1.5, 2))
  a <- RealYoudenCurve(x, d)
  b <- RealYoudenCurve(10 + 3 * x, d)
  expect_equal(b$center, 10 + 3 * a$center)
  expect_equal(b$scale, 3 * a$scale)
  expect_equal(b$c_star, a$c_star, tolerance = 1e-6)
  expect_equal(b$j_star, a$j_star, tolerance = 1e-8)
  expect_equal(b$kappa, a$kappa, tolerance = 1e-6)
  expect_equal(b$c_star_empirical, a$c_star_empirical, tolerance = 1e-8)
})

test_that("ReadNhanesCycle reads a downloaded cycle", {
  raw_dir <- test_path("..", "..", "data", "raw")
  skip_if_not(file.exists(file.path(raw_dir, "COT_J.xpt")) &&
                file.exists(file.path(raw_dir, "SMQ_J.xpt")) &&
                file.exists(file.path(raw_dir, "DEMO_J.xpt")),
              "NHANES 2017-2018 files are not in data/raw")
  out <- ReadNhanesCycle(raw_dir, "J", "2017-2018")
  expect_gt(nrow(out), 1000)
  expect_named(out, c("seqn", "cycle", "age", "sex", "race", "examined",
                      "cotinine", "below_lod", "smoker"))
  expect_true(all(out$cycle == "2017-2018"))
  expect_true(all(out$age >= 18))
  expect_true(all(out$smoker %in% c(0L, 1L)))
  expect_equal(anyDuplicated(out$seqn), 0L)
  expect_true(all(out$sex %in% c("male", "female")))
  expect_true(any(out$smoker == 1) && any(out$smoker == 0))
  # Smokers have far higher serum cotinine than nonsmokers.
  expect_gt(median(out$cotinine[out$smoker == 1], na.rm = TRUE),
            10 * median(out$cotinine[out$smoker == 0], na.rm = TRUE))
})
