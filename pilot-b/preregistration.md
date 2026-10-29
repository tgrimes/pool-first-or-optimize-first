# Re-pilot pre-registration: inference and the optimism correction under imputation

Written 2026-10-29, before any run of the re-pilot, from `proposal.md`, section 12 (the re-scope of 2026-10-29, written by the agent at the user's instruction and not yet reviewed by the user). Committed alone, so that its timestamp precedes every file in `pilot-b/results/`. Readings where section 12 leaves a case open are marked "reading". The first pilot's code (`R/`, `pilot/`) is reused unchanged; the functions below are added.

## 1. The three questions

1. Does the problem exist: does the reported index (the maximum of the pooled curve) overstate the true accuracy of the cutoff it picks, and do the pointwise Rubin's intervals, read across thresholds as a band, fail to cover the curve?
2. Is the overstatement large enough to matter at 250 per group?
3. Is there a fix: does the bootstrap-then-impute optimism correction remove at least half of the overstatement, and do the bootstrap-then-impute band and its near-optimal set cover at the nominal rate?

## 2. Notation and the procedures

As in `pilot/preregistration.md`: $J(c) = F_0(c) - F_1(c)$, $c^*$, $J^*$; $L = 20$ completed datasets with curves $\hat J_l$ and pooled curve $\bar J$. The chosen cutoff is the pool-first cutoff $\hat c = \arg\max_c \bar J(c)$ on the full empirical support (the first pilot's convention, decisions log D4); the apparent index is $A = \max_c \bar J(c)$. Its optimism is $A - J(\hat c)$, with $J$ the true curve.

**Grid.** $K = 41$ equally spaced thresholds $c_1 < \dots < c_K$ between the 10% and 90% quantiles of the observed marker values (both groups together). The bands are for $J(c_1), \dots, J(c_K)$.

**Pointwise Rubin's intervals read as a band (the default).** At each $c_k$, the first pilot's pointwise interval (binomial within-imputation variance, Rubin's degrees of freedom); simultaneous coverage means all $K$ intervals cover.

**Rubin's-rules sup-t band.** Within-imputation covariance of $\hat J_l$ at $(c_j, c_k)$, $j \le k$: $\{\hat F_{0l}(c_j) - \hat F_{0l}(c_j)\hat F_{0l}(c_k)\}/n_0 + \{\hat F_{1l}(c_j) - \hat F_{1l}(c_j)\hat F_{1l}(c_k)\}/n_1$ (the closed-form covariance of an empirical distribution function, the groups independent), averaged over $l$ to give $\bar U$; between-imputation covariance $B$ of the $L$ curves on the grid; $T = \bar U + (1 + L^{-1}) B$. The critical value $q$ is the 95% quantile of $\max_k \lvert Z_k \rvert / \sqrt{T_{kk}}$ over 5,000 draws of $Z \sim N(0, T)$ (through the eigendecomposition of $T$, negative eigenvalues set to zero; grid points with $T_{kk} = 0$ left out of the maximum). Band: $\bar J(c_k) \pm q \sqrt{T_{kk}}$.

**Bootstrap-then-impute band.** $R_B = 200$ resamples, each drawn with replacement within each disease group (group sizes kept), each imputed $M = 2$ times with the cell's engine (in the 0% cells the resample is copied twice). For resample $b$, $\hat J_{b1}$ and $\hat J_{b2}$ on the grid and their mean $\bar J_b$. Variance split (reading: section 12 says "the pointwise variance split into its bootstrap and imputation parts"; this is the split used): the imputation part per resample is $s_w^2(c) = R_B^{-1}\sum_b (\hat J_{b1}(c) - \hat J_{b2}(c))^2 / 2$; the variance of $\bar J_b$ over resamples is $V_b(c)$, which carries the sampling variance plus $s_w^2 / M$; the variance of the 20-imputation estimate is estimated as $\mathrm{SE}^2(c) = \max\{V_b(c) - s_w^2(c)/M + s_w^2(c)/L, 0\}$. The critical value $q$ is the 95% quantile over $b$ of $\max_k \lvert \bar J_b(c_k) - m(c_k) \rvert / \sqrt{V_b(c_k)}$, with $m$ the mean of $\bar J_b$ over resamples (grid points with $V_b = 0$ left out). Band: $\bar J(c_k) \pm q\,\mathrm{SE}(c_k)$, with $\bar J$ from the 20 original imputations.

**Near-optimal set** of a band with limits $L(c_k)$, $U(c_k)$: the grid points with $U(c_k) \ge \max_j L(c_j)$. It contains $c^*$ when $c^*$ lies inside the grid's range and $U$, linearly interpolated between grid points, is at least $\max_j L(c_j)$ at $c^*$. Its length is the number of grid points in the set times the grid step.

**Optimism correction.** In resample $b$, the pooled empirical curve of its $M$ completed datasets on its own support gives $\hat c_b$ and its maximum $A_b$; the original pooled curve $\bar J$ at $\hat c_b$ is $\bar J(\hat c_b)$; the optimism estimate is $o_b = A_b - \bar J(\hat c_b)$. The corrected index is $A - R_B^{-1}\sum_b o_b$.

**Normal imputation.** `mice::mice.impute.norm()` with predictors $D$, $Z$, $D \times Z$: a Bayesian linear regression with a draw of the coefficients and the residual variance before each imputation, correctly specified for this design because $X$ and $Z$ are jointly normal within each group.

## 3. Design

| Factor | Levels | Reason |
|---|---|---|
| Shape | sharp ($\delta = 2$, $\sigma_1 = 1$); flat ($\delta = 1.5$, $\sigma_1 = 2.5$) | as in the first pilot |
| Missing fraction | 0% (null), 40% (base), 60% | the null tests the bands without imputation; 60% is where the first pilot's intervals undercovered |
| Engine | predictive mean matching (5 donors); normal linear regression; none at 0% | the default, and a correctly specified model |
| $n$ per group | 250 | the realistic size of the first pilot's pass rule |
| $L$, $R_B$, $M$ | 20; 200; 2 | section 12 |
| Estimator | empirical | section 12 |

Ten data cells: per shape, one null cell and four imputed cells (two missing fractions by two engines). The missingness intercepts are the first pilot's (`MissingIntercept()`). Cell $k$ (numbered by the design table) is seeded with $20261029 + k$, L'Ecuyer-CMRG, replicates in order. Three PSOCK workers, the BLAS pinned to one thread, one cell per task (`chunk.size = 1`, a lesson of the first run).

**Replicates and time box.** $R = 500$ per cell (MCSE of a coverage near 0.95: 0.010). Before the run, ten replicates of every cell are timed; if the projection on three workers exceeds one hour, $R$ is lowered to the largest multiple of 100 that fits, recorded in `pilot-b/decisions.md`; the pass rule is unchanged.

**Measures per cell**, each with its MCSE:

- the optimism of the apparent index, mean of $A - J(\hat c)$, and its bias against $J^*$;
- the corrected index's bias against $J(\hat c)$ and against $J^*$, and the ratio of its mean bias to the apparent index's against $J(\hat c)$ (delta method);
- the simultaneous coverage of the three bands and their mean half-widths over the grid;
- the coverage of $c^*$ by the near-optimal sets of the two sup-t bands and their mean lengths;
- the pointwise coverage of Rubin's interval at $c^*$;
- for the note: the pooling-order gap, its prediction $\kappa \hat B_c / 2$, and the ratio of root mean squared errors of the cutoff, optimize first over pool first;
- the realized missing fraction, and the bootstrap critical values $q$ (mean over replicates).

## 4. Cells and checks with a known answer

Tests in `tests/testthat/`, saved by `pilot-b/pilot.R` to `pilot-b/results/known_answers.rds` before the run:

- the covariance of an empirical distribution function at two points against $\{F(a) - F(a)F(b)\}/n$, by simulation;
- the sup-t critical value for $K$ independent coordinates against $\Phi^{-1}\{(1 + 0.95^{1/K})/2\}$, for $K = 41$ and $K = 1$ (1.96);
- the variance split on synthetic resamples with known sampling and imputation variances;
- the optimism of a bootstrap whose resamples reproduce the original curve: exactly zero;
- the near-optimal set of a band that covers the true curve contains $c^*$;
- the normal imputation under the correct model: the mean of the imputed values matches the true conditional mean within three MCSE.

From the run itself: in the 0% cells the pooling-order gap is exactly zero in every replicate.

## 5. The pass rule, with numbers

Base cell: sharp, 40% missing, 250 per group, predictive mean matching. Its normal twin: the same with normal imputation. The 60% cell: the base cell with 60% missing. A threshold is met when the point estimate is on the passing side; an estimate within three MCSE of its threshold is near.

1. **Q1 passes** if in the base cell the mean optimism $A - J(\hat c)$ exceeds 3 MCSE, and the simultaneous coverage of the pointwise Rubin's intervals is below 0.90.
2. **Q2 passes** if the mean optimism is at least 0.01 in the base cell or in the 60% cell.
3. **Q3 passes** if all of: (a) in the base cell, $\lvert$mean of corrected $- J(\hat c)\rvert \le 0.5\,\lvert$mean of $A - J(\hat c)\rvert$; (b) the bootstrap-then-impute band's simultaneous coverage lies in $[0.92, 0.98]$ in the base cell and in its normal twin; (c) its near-optimal set contains $c^*$ in at least 0.92 of replicates in the base cell and in its normal twin.

The status: `piloted-fail` if Q1 fails, or Q3 fails with no deciding estimate near its threshold; `piloted-pass` if all three pass and no deciding estimate is near; `piloted-close-call` otherwise, stated both ways. Nearness is judged as in the first pre-registration (a rule met through any clause is near only if every met clause is near; a rule that needs all its clauses is near, when met, if any clause is near, and when failed, if every failed clause is near). `pilot-b/verdict.R` applies the rule to `pilot-b/results/cell_summaries.rds`.

## 6. Reported whatever the outcome

Every cell with every measure and its MCSE, the Rubin sup-t band beside the bootstrap-then-impute band, the flat and 60% cells beside the base cell, the known-answer checks, the timing run and the runtime, and any deviation from this file, marked as such.
