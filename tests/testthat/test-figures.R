DrawsWithoutError <- function(code) {
  path <- tempfile(fileext = ".pdf")
  grDevices::pdf(path)
  on.exit({
    grDevices::dev.off()
    unlink(path)
  })
  expect_null(code)
}

test_that("the cell-summary figures draw from pilot-c's summaries", {
  s <- readRDS(test_path("fixtures", "pilot-c-cell-summaries.rds"))
  labels <- CellLabel(s)
  DrawsWithoutError(PlotBandCoverage(s, labels))
  DrawsWithoutError(PlotSets(s, labels))
  DrawsWithoutError(PlotOptimism(s, labels))
})

test_that("the figure functions restore the graphics parameters", {
  s <- readRDS(test_path("fixtures", "pilot-c-cell-summaries.rds"))
  path <- tempfile(fileext = ".pdf")
  grDevices::pdf(path)
  on.exit({
    grDevices::dev.off()
    unlink(path)
  })
  before <- graphics::par("mar", "mfrow")
  PlotSets(s, CellLabel(s))
  expect_equal(graphics::par("mar", "mfrow"), before)
})

test_that("PlotNhanesCurve draws a curve with and without a reference", {
  grid <- seq(-1, 3, length.out = 21)
  curve <- list(grid = grid, empirical = pmax(0, 0.5 - (grid - 1)^2 / 8),
                kernel = pmax(0, 0.5 - (grid - 1)^2 / 8), c_star = 1,
                center = -1, scale = 1)
  DrawsWithoutError(PlotNhanesCurve(curve))
  DrawsWithoutError(PlotNhanesCurve(curve, reference_cutoff = 3.63))
})

test_that("PlotGap and PlotApplication draw", {
  s <- data.frame(shape = c("sharp", "flat"), engine = c("pmm", "norm"),
                  miss_rate = 0.4, gap = c(0.003, 0.004),
                  gap_mcse = c(1e-4, 1e-4), pred_gap = c(0.0028, 0.0045))
  DrawsWithoutError(PlotGap(s))
  grid <- seq(-1, 2, length.out = 9)
  est <- 0.6 - (grid - 0.5)^2 / 4
  a <- list(grid = grid, estimate = est, c_hat = 0.5,
            hybrid = list(lower = est - 0.05, upper = est + 0.05),
            sets = list(comp_hybrid = abs(grid - 0.5) < 0.6))
  DrawsWithoutError(PlotApplication(a, benchmark = est - 0.01,
                                    reference = 0.56))
})
