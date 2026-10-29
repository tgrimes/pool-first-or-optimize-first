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
