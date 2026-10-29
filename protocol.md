# Simulation protocol (ADEMP)

Inference for the Youden curve of a multiply imputed biomarker. Written 2026-10-29, at the design stop of stage 3, from the design the user approved (`log/03-manuscript.md`, section 3.2 and D-S3), before any run of this design. Changes after a production run are recorded at the bottom with the date and the reason. The framework is ADEMP (Morris, White, and Crowther 2019).

## Study S1: the band, the near-optimal set, and the corrected index

**Aims.**

1. Does the bootstrap-then-impute band, with a bootstrap or a normal-law (hybrid) critical value, cover the whole Youden curve over the grid in 95% of replicates, under predictive mean matching and under a correctly specified normal imputation model, across peak shapes, group sizes, missing fractions, and group balance? How does it compare with the Rubin's-rules sup-t band and the pointwise Rubin's intervals read as a band? Where it falls short under predictive mean matching, is the shortfall bias of the averaged curve or a variance that is too small?
2. Does the comparison-based near-optimal set contain the grid's best threshold in at least 95% of replicates, how long is it against the band-based set and against the true range of thresholds within 0.01 of $J^*$, and does the critical value at the estimated best threshold shorten it without losing coverage?
3. Does the bootstrap optimism correction with as many imputations per resample as the analysis remove the optimism of the reported index against the true accuracy of the chosen cutoff?
4. As a note: how large is the pooling-order gap against $\kappa \hat B_c / 2$, and are the averaged cutoff (optimize first) and the bagged cutoff more accurate than the pooled argmax?

**Data-generating mechanisms.** The marker is $X \mid D = 0 \sim N(0, 1)$ and $X \mid D = 1 \sim N(\delta, \sigma_1^2)$, with a subject called positive when $X > c$; the auxiliary is $Z = X + e$, $e \sim N(0, 1)$; $X$ is missing with probability $\mathrm{expit}(\alpha_0 + Z + 0.5 D)$, missing at random given $Z$ and $D$, with $\alpha_0$ solved for the target missing fraction given the group shares (`MissingIntercept()`); $D$ and $Z$ are always observed.

Factors varied:

| Factor | Levels | Reason |
|---|---|---|
| Shape | sharp ($\delta = 2$, $\sigma_1 = 1$: $c^* = 1$, $J^* = 0.683$, $\kappa = 0.484$); flat ($\delta = 1.5$, $\sigma_1 = 2.5$: $c^* = 1.355$, $J^* = 0.435$, $\kappa = 0.220$); separated ($\delta = 3$, $\sigma_1 = 1$: $c^* = 1.5$, $J^* = 0.866$, $\kappa = 0.389$) | curvature and height of the peak; the NHANES curve has $\hat\kappa = 0.23$ and $\hat J^* = 0.87$ |
| Group size | 250 per group in every shape; 100 and 1,000 for the sharp shape | a small clinical study to an NHANES cycle |
| Missing fraction | 0, 0.2, 0.4, 0.6 | from complete data to sparse donors |
| Imputation | predictive mean matching with 5 donors, normal linear regression (every missing cell); predictive mean matching with 10 donors, complete cases (sharp, 250) | the default; the correct model; the recommended donor pool; no imputation |
| Group balance | equal; 100 cases and 400 controls (sharp; 0 and 0.4 with each of the two main engines) | the NHANES groups are 1 to 4.4 |

Factors fixed, and why: $L = 20$ imputations (the analysis an applied paper runs); the empirical estimator (the common one, and the cube-root case); the auxiliary's strength (correlation about 0.71 within groups, as in the pilots); the missingness coefficients (as in the pilots); missingness at random (the claims are made under it); the disease status observed (verification bias is another problem).

The design, five arms, 44 cells: (A) three shapes at 250 per group, each with a cell without missing values and the three missing fractions crossed with the two main engines, 21 cells; (B) the sharp shape at 100 and at 1,000 per group, the same seven cells each, 14 cells; (C) the sharp shape at 250 with ten donors at the three missing fractions, 3 cells; (D) the same with complete cases, 3 cells; (E) the sharp shape with 100 cases and 400 controls, without missing values and at 0.4 with each main engine, 3 cells. The base cell is sharp, 250 per group, 0.4 missing, predictive mean matching with 5 donors.

Cells where the answer is known: every cell without missing values, where the 20 completed datasets are identical, the bands are complete-data bands, and the pooling-order gap and the between-imputation variance of the cutoffs are exactly zero in every replicate. Known answers checked in `tests/testthat/`: the comparison critical value for independent coordinates, $\Phi^{-1}(0.95)$; the hybrid band's critical value for 41 independent coordinates, $\Phi^{-1}\{(1 + 0.95^{1/41})/2\}$; the covariance split on synthetic resamples; a set built on the true curve contains the best grid point; a reproducing bootstrap has optimism exactly zero; the separated shape's $c^* = \delta / 2$ and $J^* = 2\Phi(\delta/2) - 1$; the missingness intercept's fraction with unequal groups.

**Estimands.** The Youden curve $J(c) = F_0(c) - F_1(c)$ on each replicate's grid; the grid's best threshold $c_{k^*}$, $k^* = \arg\max_k J(c_k)$; $c^* = \arg\max_c J(c)$ and $J^* = J(c^*)$; the true accuracy $J(\hat c)$ of the chosen cutoff and the regret $J^* - J(\hat c)$.

**Methods.** In every replicate, with $L = 20$ completed datasets (`MiYoudenInference()`, called by `RunReplicateC()`):

- the pooled empirical curve $\bar J$, its maximizer $\hat c$ (the midpoint of the maximizing interval, the mean of the midpoints for ties), and the reported index $\bar J(\hat c)$;
- a grid of 41 thresholds between the 10% and 90% quantiles of all completed values;
- the pointwise Rubin's intervals and the Rubin's-rules sup-t band, from the binomial within-imputation covariance and the between-imputation covariance, the critical value from 5,000 normal draws;
- 1,000 resamples within disease groups, each imputed twice; the covariance of the 20-imputation curve $\Sigma = V - W/2 + W/20$ with negative eigenvalues set to zero;
- the bootstrap band (critical value the 95% quantile of the resamples' largest standardized deviation) and the hybrid band (critical value from 5,000 draws of $N(0, \Sigma)$), each $\bar J(c_k) \pm q\,\mathrm{SE}_k$;
- the band-based set $\{k : U_k \ge \max_j L_j\}$ and the comparison-based set $\{k : \bar J(c_j) - \bar J(c_k) \le q_D\,\mathrm{SE}_{jk} \text{ for all } j \ne k\}$ of each construction, with $q_D$ the largest over grid points of the per-point one-sided 95% quantile, and, as the plug-in variant, the per-point quantile at the estimated best grid point;
- the optimism correction: 100 further resamples imputed 20 times each, the corrected index $\bar J(\hat c) - \bar o$ with $o_b = \bar J_b(\hat c_b) - \bar J(\hat c_b)$; the same from the first 200 curve resamples with 2 imputations, as secondary;
- optimize first: the mean of the per-dataset cutoffs and of their maxima; the bagged cutoff: the mean cutoff of the 100 matched resamples.

Imputation: `mice::mice.impute.pmm()` (type 1 matching, 5 or 10 donors) or `mice::mice.impute.norm()`, once per imputation, with predictors $D$, $Z$, $D \times Z$, less any that are constant or collinear among the observed rows (amendment of 2026-10-29, below); complete cases drop the subjects with $X$ missing and run the same procedure without imputation. Software: R 4.5.2, `mice` 3.19.0, the package `micutoff` in this repository; versions in `results/session_info.txt`.

Left out, with reasons (D-S3): the kernel estimator; the nearest-neighbour engine of Long, Zhang, and Hsu (2011), not proper with one auxiliary; impute-then-bootstrap, for which the Rubin's-rules band stands, since it uses the closed-form within-imputation covariance a bootstrap of each completed dataset estimates; the complete-case intervals of Bantis, Nakas, and Reiser (2019), with complete cases entering as an engine instead; the discrete covariate, which goes to the application and the supplement; the auxiliary's strength.

**Performance measures**, per cell, each with its Monte Carlo standard error:

- simultaneous coverage of the true curve over the grid, and mean half-width, of the pointwise, Rubin's-rules, bootstrap, and hybrid bands;
- the share of replicates in which each set (band-based, comparison-based, plug-in; bootstrap and hybrid) contains $c_{k^*}$; its mean length (points times the grid step); its length against the band-based set's (ratio of means, delta-method MCSE) and against the length of $\{c : J(c) \ge J^* - 0.01\}$;
- the optimism $\bar J(\hat c) - J(\hat c)$; the bias of the 20- and 2-imputation corrected indices against $J(\hat c)$ and their ratio to the optimism; the bias of the reported index against $J^*$;
- the bias, empirical SE, and RMSE of $\hat c$, the RMSE of the averaged and bagged cutoffs and their ratios to $\hat c$'s; the regret;
- the pooling-order gap and $\kappa \hat B_c / 2$, with the ratio of their means;
- at $c_{k^*}$: the averaged curve's bias, the ratio of its Monte Carlo SD to the mean standard error from $\Sigma$ and from Rubin's rules;
- the share of replicates whose grid contains $c^*$, the realized missing fraction, and the number of subjects analysed.

A difference is called nonzero only when it exceeds about three Monte Carlo standard errors. No method is a hypothesis test, so no power cells are planned; the band's width and the sets' length, against the true range and across the size gradient, play power's role.

**Replicates.** 2,000 per cell in the production run, giving a Monte Carlo standard error of about 0.005 for a coverage near 0.95 (`[TO CONFIRM: 2,000 replicates, about 11.5 hours on seven workers, or 1,300, about 7.5 hours]{.tc}`, the spec's open question). The quick run uses 100 per cell (about 0.022 for a coverage near 0.95); its replicates are the production run's first block of each cell.

## Common

Seeds: replicates run in seeded blocks of 100; block $b$ of cell $k$ uses the L'Ecuyer-CMRG generator seeded with $20261101 + 1000k + b$, so results do not depend on the worker; the base seed differs from pilot-c's ($20261030$), so the 0.6 predictive-mean-matching cells are a fresh recheck of pilot-c's (D-S8 of the stage 2 log). Workers: seven PSOCK workers with the BLAS pinned to one thread, one block per task, `parLapplyLB()` with `chunk.size = 1` (the user's allowance of eight cores, D-S2). Outputs: `results/simulation_replicates.rds` (per replicate, git-ignored), `results/cell_summaries.rds` and `.csv` (committed), `results/design.rds`, `results/run_info.rds` (the run label, replicates, cells, date, `n_rep_production`), `results/session_info.txt`. The manuscript reads the summaries at render time. The application is `analysis/02_application.R`, with its own run file `results/application_run_info.rds`.

## Amendments before the production run

| Date | Change | Reason |
|---|---|---|
| 2026-10-29 | Predictors constant or collinear among the observed rows are dropped before each call of `mice.impute.pmm()` or `mice.impute.norm()` (`FullRankColumns()`); data without such columns are imputed exactly as before. The parallel runner saves finished blocks when a block fails. | The first quick run stopped in cell 27 (sharp, 100 per group, 60% missing, predictive mean matching), replicate 9, where 10 of 100 cases were observed and a resample left the predictors collinear; `mice`'s univariate functions stop on collinear predictors outside `mice()`, which would have removed them. No result of that run was read: the run saved nothing. |

## Changes after production

| Date | Change | Reason |
|---|---|---|
| | | |
