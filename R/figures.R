# Figure functions shared by the manuscript, the slides, and the poster.

#' Left margin, in lines, that fits row labels
#'
#' @param labels Row labels.
#' @param cex Character expansion of the labels.
#' @return Margin lines: about half a line per character at `cex = 0.8`,
#'   plus one.
#' @keywords internal
LabelMargin <- function(labels, cex = 0.8) {
  1 + max(nchar(labels)) * 0.55 * cex
}
# Each draws one figure in base graphics from the per-cell summaries of
# SummarizeAllCellsC() (or the NHANES description) and returns NULL
# invisibly. Ported from pilot-c's report.

#' Simultaneous coverage of the bands in every cell
#'
#' @param s Per-cell summaries.
#' @param labels Row labels, one per cell (`CellLabel()`).
#' @param limits Reference lines drawn dashed beside the nominal level.
#' @param nominal The nominal level, drawn solid.
#' @return `NULL`, invisibly.
#' @export
PlotBandCoverage <- function(s, labels, limits = c(0.93, 0.97),
                             nominal = 0.95) {
  op <- graphics::par(mar = c(4.2, LabelMargin(labels), 1, 1))
  on.exit(graphics::par(op))
  y <- seq_len(nrow(s))
  graphics::plot(s$cover_boot, y - 0.12,
                 xlim = c(min(0.3, s$cover_pointwise), 1),
                 ylim = c(0.5, nrow(s) + 0.5), yaxt = "n", ylab = "",
                 xlab = "Simultaneous coverage over the grid", pch = 19)
  graphics::segments(s$cover_boot - 2 * s$cover_boot_mcse, y - 0.12,
                     s$cover_boot + 2 * s$cover_boot_mcse, y - 0.12)
  graphics::points(s$cover_hybrid, y + 0.12, pch = 17, col = "#2c7fb8")
  graphics::segments(s$cover_hybrid - 2 * s$cover_hybrid_mcse, y + 0.12,
                     s$cover_hybrid + 2 * s$cover_hybrid_mcse, y + 0.12,
                     col = "#2c7fb8")
  graphics::points(s$cover_rubin, y, pch = 0)
  graphics::points(s$cover_pointwise, y, pch = 4, col = "#d95f02")
  graphics::abline(v = nominal, col = "grey40")
  graphics::abline(v = limits, lty = 2, col = "grey40")
  graphics::axis(2, at = y, labels = labels, las = 1, cex.axis = 0.8)
  invisible(NULL)
}

#' Coverage and length of the near-optimal sets in every cell
#'
#' Left panel: the share of replicates in which each set contains the
#' grid's best threshold; right panel: each set's mean length, with the
#' length of the true range of thresholds within a tolerance of \eqn{J^*}.
#' When the summaries carry the plug-in hybrid set (`compplug_hybrid`), it
#' is drawn as orange diamonds.
#'
#' @param s Per-cell summaries.
#' @param labels Row labels, one per cell.
#' @param limit Reference line for the coverage (the nominal level).
#' @return `NULL`, invisibly.
#' @export
PlotSets <- function(s, labels, limit = 0.95) {
  op <- graphics::par(mfrow = c(1, 2), mar = c(4.2, LabelMargin(labels), 1,
                                                0.5))
  on.exit(graphics::par(op))
  y <- seq_len(nrow(s))
  graphics::plot(s$compset_boot, y - 0.12,
                 xlim = c(min(0.85, s$compset_boot, s$compset_hybrid), 1),
                 ylim = c(0.5, nrow(s) + 0.5), yaxt = "n", ylab = "",
                 xlab = "Set contains the best threshold", pch = 19)
  graphics::points(s$compset_hybrid, y + 0.12, pch = 17, col = "#2c7fb8")
  graphics::points(s$bandset_boot, y - 0.12, pch = 1)
  graphics::points(s$bandset_hybrid, y + 0.12, pch = 2, col = "#2c7fb8")
  if (!is.null(s$compplug_hybrid)) {
    graphics::points(s$compplug_hybrid, y + 0.3, pch = 5, col = "#d95f02")
  }
  graphics::abline(v = limit, col = "grey40")
  graphics::axis(2, at = y, labels = labels, las = 1, cex.axis = 0.8)
  graphics::par(mar = c(4.2, 0.5, 1, 1))
  graphics::plot(s$compset_boot_length, y - 0.12,
                 xlim = c(0, max(s$bandset_boot_length,
                                 s$bandset_hybrid_length)),
                 ylim = c(0.5, nrow(s) + 0.5), yaxt = "n", ylab = "",
                 xlab = "Mean length", pch = 19)
  graphics::points(s$compset_hybrid_length, y + 0.12, pch = 17,
                   col = "#2c7fb8")
  graphics::points(s$bandset_boot_length, y - 0.12, pch = 1)
  graphics::points(s$bandset_hybrid_length, y + 0.12, pch = 2,
                   col = "#2c7fb8")
  if (!is.null(s$compplug_hybrid_length)) {
    graphics::points(s$compplug_hybrid_length, y + 0.3, pch = 5,
                     col = "#d95f02")
  }
  graphics::points(s$true_region_length, y, pch = 3, col = "grey40")
  invisible(NULL)
}

#' Optimism of the reported index and the bias of its corrections
#'
#' @param s Per-cell summaries.
#' @param labels Row labels, one per cell.
#' @param reference A reference line drawn dashed (one point of the index).
#' @return `NULL`, invisibly.
#' @export
PlotOptimism <- function(s, labels, reference = 0.01) {
  op <- graphics::par(mar = c(4.2, LabelMargin(labels), 1, 1))
  on.exit(graphics::par(op))
  y <- seq_len(nrow(s))
  rng <- range(0, s$optimism + 2 * s$optimism_mcse, s$corrected_bias_2,
               s$corrected_bias_20 - 2 * s$corrected_bias_20_mcse)
  graphics::plot(s$optimism, y, xlim = rng, ylim = c(0.5, nrow(s) + 0.5),
                 yaxt = "n", ylab = "",
                 xlab = "Index minus the true accuracy of the chosen cutoff",
                 pch = 1)
  graphics::segments(s$optimism - 2 * s$optimism_mcse, y,
                     s$optimism + 2 * s$optimism_mcse, y)
  graphics::points(s$corrected_bias_20, y + 0.2, pch = 19)
  graphics::segments(s$corrected_bias_20 - 2 * s$corrected_bias_20_mcse,
                     y + 0.2,
                     s$corrected_bias_20 + 2 * s$corrected_bias_20_mcse,
                     y + 0.2)
  graphics::points(s$corrected_bias_2, y - 0.2, pch = 17, col = "grey50")
  graphics::abline(v = 0, col = "grey40")
  graphics::abline(v = reference, lty = 2, col = "grey40")
  graphics::axis(2, at = y, labels = labels, las = 1, cex.axis = 0.8)
  invisible(NULL)
}

#' The full-data Youden curve of the application
#'
#' @param curve The output of `RealYoudenCurve()` (with `cutoff` fields): the
#'   grid, the empirical and kernel curves, the kernel maximizer, and the
#'   centre and scale of the standardization.
#' @param reference_cutoff Optional published cutoff in ng/mL, drawn dashed.
#' @return `NULL`, invisibly.
#' @export
PlotNhanesCurve <- function(curve, reference_cutoff = NULL) {
  op <- graphics::par(mar = c(4.2, 4.2, 1, 1))
  on.exit(graphics::par(op))
  graphics::plot(curve$grid, curve$empirical, type = "s", ylim = c(0, 0.9),
                 xlab = "log10 cotinine, standardized by the nonsmokers",
                 ylab = "Youden index J(c)")
  graphics::lines(curve$grid, curve$kernel, col = "#2c7fb8", lwd = 2)
  graphics::abline(v = curve$c_star, lty = 1, col = "grey30")
  if (!is.null(reference_cutoff)) {
    graphics::abline(v = (log10(reference_cutoff) - curve$center) /
                       curve$scale, lty = 2, col = "grey30")
  }
  invisible(NULL)
}

#' The pooling-order gap against its quadratic approximation
#'
#' One point per cell with missing values: the mean gap between the
#' optimize-first and pool-first indices against the mean of
#' \eqn{\kappa \hat B_c / 2}, with plus and minus two MCSE, on log scales,
#' and the identity line.
#'
#' @param s Per-cell summaries from `SummarizeStudy()`.
#' @return `NULL`, invisibly.
#' @export
PlotGap <- function(s) {
  s <- s[s$miss_rate > 0 & s$engine != "cc", ]
  op <- graphics::par(mar = c(4.2, 4.4, 1, 1))
  on.exit(graphics::par(op))
  col <- ifelse(s$engine == "norm", "#2c7fb8", "black")
  pch <- c(sharp = 19, flat = 17, separated = 15)[s$shape]
  rng <- range(c(s$pred_gap, s$gap - 2 * s$gap_mcse,
                 s$gap + 2 * s$gap_mcse))
  rng[1] <- max(rng[1], min(s$pred_gap) / 2)
  graphics::plot(s$pred_gap, s$gap, log = "xy", xlim = rng, ylim = rng,
                 pch = pch, col = col,
                 xlab = "Mean of kappa * B_c / 2", ylab = "Mean gap")
  graphics::segments(s$pred_gap, pmax(s$gap - 2 * s$gap_mcse, rng[1]),
                     s$pred_gap, s$gap + 2 * s$gap_mcse, col = col)
  graphics::abline(0, 1, lty = 2, col = "grey40")
  graphics::legend("topleft", c("sharp", "flat", "separated", "PMM",
                                "normal"),
                   pch = c(19, 17, 15, 19, 19),
                   col = c("grey30", "grey30", "grey30", "black", "#2c7fb8"),
                   bty = "n", cex = 0.8)
  invisible(NULL)
}

#' The application's pooled curve with its band and near-optimal set
#'
#' @param a One analysis from `SummarizeAnalysis()`.
#' @param construction `"hybrid"` or `"boot"`.
#' @param benchmark Optional curve on the same grid (the complete-case
#'   curve), drawn in grey.
#' @param reference Optional threshold on the analysis scale, drawn dashed.
#' @param main Panel title.
#' @return `NULL`, invisibly.
#' @export
PlotApplication <- function(a, construction = "hybrid", benchmark = NULL,
                            reference = NULL, main = "") {
  band <- a[[construction]]
  in_set <- a$sets[[paste0("comp_", construction)]]
  ylim <- range(c(band$lower, band$upper, benchmark))
  ylim[1] <- ylim[1] - 0.05 * diff(ylim)
  graphics::plot(a$grid, a$estimate, type = "n", ylim = ylim,
                 xlab = "log10 cotinine (ng/mL)", ylab = "Youden index J(c)",
                 main = main, cex.main = 0.9)
  graphics::polygon(c(a$grid, rev(a$grid)), c(band$lower, rev(band$upper)),
                    col = "grey88", border = NA)
  if (!is.null(benchmark)) {
    graphics::lines(a$grid, benchmark, col = "grey45", lwd = 2)
  }
  graphics::lines(a$grid, a$estimate, lwd = 2)
  graphics::points(a$grid[in_set], rep(ylim[1], sum(in_set)), pch = 15,
                   cex = 0.8, col = "#d95f02")
  graphics::abline(v = a$c_hat, col = "grey30")
  if (!is.null(reference)) graphics::abline(v = reference, lty = 2)
  invisible(NULL)
}
