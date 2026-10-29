# The binormal marker model and its known answers.

#' True Youden curve of a binormal marker
#'
#' With the marker \eqn{X \sim N(0, 1)} in group 0 and \eqn{N(\delta,
#' \sigma_1^2)} in group 1, and a subject called positive when \eqn{X > c},
#' the Youden curve is \eqn{J(c) = F_0(c) - F_1(c)}.
#'
#' @param cutoff Numeric vector of thresholds.
#' @param delta Mean of the marker in group 1.
#' @param sigma1 Standard deviation of the marker in group 1.
#' @return Numeric vector, \eqn{J} at each threshold.
#' @export
TrueYouden <- function(cutoff, delta, sigma1) {
  stats::pnorm(cutoff) - stats::pnorm((cutoff - delta) / sigma1)
}

#' Known answers for a binormal shape
#'
#' Computes the optimal cutoff, the maximum of the Youden curve, its
#' curvature \eqn{\kappa = -J''(c^*)}, and its third derivative
#' \eqn{\tau = J'''(c^*)}, from the closed-form derivatives of the normal
#' density.
#'
#' @param delta Mean of the marker in group 1.
#' @param sigma1 Standard deviation of the marker in group 1.
#' @return A list with `delta`, `sigma1`, `c_star`, `j_star`, `kappa`, `tau`.
#' @export
MarkerTruth <- function(delta, sigma1) {
  # Search between the group-0 mean and well past the group-1 mean; the
  # binormal curve has one interior maximum there.
  opt <- stats::optimize(TrueYouden, c(-2, delta + 4 * sigma1),
                         delta = delta, sigma1 = sigma1,
                         maximum = TRUE, tol = 1e-12)
  c_star <- opt$maximum
  u <- (c_star - delta) / sigma1
  # Derivatives of phi(c) - phi(u) / sigma1, with u = (c - delta) / sigma1.
  j2 <- -c_star * stats::dnorm(c_star) + u * stats::dnorm(u) / sigma1^2
  j3 <- (c_star^2 - 1) * stats::dnorm(c_star) -
    (u^2 - 1) * stats::dnorm(u) / sigma1^3
  list(delta = delta, sigma1 = sigma1, c_star = c_star,
       j_star = opt$objective, kappa = -j2, tau = j3)
}

#' Intercept of the missingness model for a target missing fraction
#'
#' The marker is missing with probability
#' \eqn{\mathrm{expit}(\alpha_0 + b_z Z + b_d D)}, with \eqn{Z = X + e},
#' \eqn{e \sim N(0, 1)}, and equal group sizes. Solves for \eqn{\alpha_0} so
#' that the expected missing fraction over both groups is `rate`.
#'
#' @param rate Target missing fraction, strictly between 0 and 1.
#' @param delta Mean of the marker in group 1.
#' @param sigma1 Standard deviation of the marker in group 1.
#' @param b_z Coefficient of the auxiliary.
#' @param b_d Coefficient of the disease status.
#' @return The intercept \eqn{\alpha_0}.
#' @export
MissingIntercept <- function(rate, delta, sigma1, b_z = 1, b_d = 0.5) {
  stopifnot(rate > 0, rate < 1)
  ExpectedRate <- function(alpha0) {
    m0 <- stats::integrate(function(z) {
      stats::plogis(alpha0 + b_z * z) * stats::dnorm(z, 0, sqrt(2))
    }, -Inf, Inf)$value
    m1 <- stats::integrate(function(z) {
      stats::plogis(alpha0 + b_z * z + b_d) *
        stats::dnorm(z, delta, sqrt(sigma1^2 + 1))
    }, -Inf, Inf)$value
    (m0 + m1) / 2
  }
  stats::uniroot(function(a) ExpectedRate(a) - rate, c(-20, 20),
                 tol = 1e-10)$root
}

#' Simulate one dataset from the pilot's marker model
#'
#' @param n Subjects per group.
#' @param delta Mean of the marker in group 1.
#' @param sigma1 Standard deviation of the marker in group 1.
#' @param alpha0 Intercept of the missingness model, or `NA` for no missing
#'   values.
#' @param b_z,b_d Coefficients of the missingness model.
#' @return A data frame with `d` (0 or 1), `x_full`, `z`, `observed`
#'   (logical), and `x` (`NA` where missing).
#' @export
SimulateMarkerData <- function(n, delta, sigma1, alpha0 = NA,
                               b_z = 1, b_d = 0.5) {
  d <- rep(c(0L, 1L), each = n)
  x_full <- c(stats::rnorm(n), stats::rnorm(n, delta, sigma1))
  z <- x_full + stats::rnorm(2 * n)
  if (is.na(alpha0)) {
    observed <- rep(TRUE, 2 * n)
  } else {
    p_miss <- stats::plogis(alpha0 + b_z * z + b_d * d)
    observed <- stats::runif(2 * n) >= p_miss
  }
  x <- ifelse(observed, x_full, NA_real_)
  data.frame(d = d, x_full = x_full, z = z, observed = observed, x = x)
}
