# The two imputation engines. Each returns an N x L matrix of completed
# marker values: observed rows are unchanged, missing rows hold the draws.

#' Multiple imputation by predictive mean matching
#'
#' Calls `mice::mice.impute.pmm()` once per imputation with the predictors
#' \eqn{D}, \eqn{Z}, and \eqn{D \times Z}. Only the marker is missing and the
#' predictors are complete, so one call per imputation is the univariate
#' step that `mice()` runs for this pattern.
#'
#' @param x Marker values, `NA` where missing.
#' @param d Disease status (0 or 1).
#' @param z Auxiliary variable.
#' @param n_imp Number of imputations \eqn{L}.
#' @param donors Number of donors.
#' @return An N x `n_imp` matrix of completed marker values.
#' @export
ImputePmm <- function(x, d, z, n_imp, donors = 5L) {
  observed <- !is.na(x)
  predictors <- cbind(d = d, z = z, dz = d * z)
  completed <- matrix(x, nrow = length(x), ncol = n_imp)
  for (l in seq_len(n_imp)) {
    completed[!observed, l] <- mice::mice.impute.pmm(
      y = x, ry = observed, x = predictors, donors = donors)
  }
  completed
}

#' Candidate donors of the nearest-neighbour engine
#'
#' For each missing subject, the `k` observed subjects with the same disease
#' status that are closest in the weighted distance
#' \eqn{\{w_1 (s_{1i} - s_{1j})^2 + w_2 (s_{2i} - s_{2j})^2\}^{1/2}} on two
#' standardized scores (Long, Zhang, and Hsu 2011, section 2.3).
#'
#' @param s1,s2 Standardized prediction and propensity scores, one per
#'   subject.
#' @param observed Logical, the marker is observed.
#' @param d Disease status.
#' @param k Number of neighbours.
#' @param weights The two weights, summing to one.
#' @return A `k` x (number missing) integer matrix of donor row indices, the
#'   columns in the order of `which(!observed)`.
#' @export
NearestDonors <- function(s1, s2, observed, d, k = 3L,
                          weights = c(0.5, 0.5)) {
  missing_idx <- which(!observed)
  out <- matrix(NA_integer_, nrow = k, ncol = length(missing_idx))
  for (g in unique(d[missing_idx])) {
    m_g <- missing_idx[d[missing_idx] == g]
    o_g <- which(observed & d == g)
    dist2 <- weights[1] * outer(s1[m_g], s1[o_g], "-")^2 +
      weights[2] * outer(s2[m_g], s2[o_g], "-")^2
    nearest <- apply(dist2, 1, function(r) o_g[order(r)[seq_len(k)]])
    out[, match(m_g, missing_idx)] <- matrix(nearest, nrow = k)
  }
  out
}

#' Multiple imputation by the nearest-neighbour method of Long et al.
#'
#' The doubly robust method with a bootstrap step (MIB-2 in Long, Zhang, and
#' Hsu 2011, sections 2.3 and 2.4). Before each imputation, the prediction
#' model (linear regression of the marker on the working covariates, among
#' observed subjects) and the propensity model (logistic regression of the
#' observed indicator on the same covariates) are refit on a bootstrap
#' sample of all subjects. Both linear predictors are computed for every
#' subject of the original data and standardized to mean 0 and standard
#' deviation 1; each missing value is replaced by the marker of one of the
#' `k` nearest observed subjects with the same disease status, drawn at
#' random.
#'
#' @param x Marker values, `NA` where missing.
#' @param d Disease status (0 or 1).
#' @param z Auxiliary variable.
#' @param n_imp Number of imputations \eqn{L}.
#' @param k Number of neighbours.
#' @param weights Weights of the two scores in the distance.
#' @param bootstrap Refit the working models on a bootstrap sample before
#'   each imputation.
#' @return An N x `n_imp` matrix of completed marker values.
#' @export
ImputeNearestNeighbour <- function(x, d, z, n_imp, k = 3L,
                                   weights = c(0.5, 0.5), bootstrap = TRUE) {
  observed <- !is.na(x)
  n_all <- length(x)
  w_mat <- cbind(1, d, z, d * z)
  completed <- matrix(x, nrow = n_all, ncol = n_imp)
  n_miss <- sum(!observed)
  if (n_miss == 0) return(completed)
  for (l in seq_len(n_imp)) {
    idx <- seq_len(n_all)
    if (bootstrap) idx <- sample.int(n_all, n_all, replace = TRUE)
    fit_rows <- idx[observed[idx]]
    alpha <- stats::lm.fit(w_mat[fit_rows, , drop = FALSE],
                           x[fit_rows])$coefficients
    beta <- suppressWarnings(stats::glm.fit(
      w_mat[idx, , drop = FALSE], as.numeric(observed[idx]),
      family = stats::binomial())$coefficients)
    alpha[is.na(alpha)] <- 0
    beta[is.na(beta)] <- 0
    s1 <- as.vector(scale(w_mat %*% alpha))
    s2 <- as.vector(scale(w_mat %*% beta))
    donors <- NearestDonors(s1, s2, observed, d, k = k, weights = weights)
    pick <- donors[cbind(sample.int(k, n_miss, replace = TRUE),
                         seq_len(n_miss))]
    completed[!observed, l] <- x[pick]
  }
  completed
}
