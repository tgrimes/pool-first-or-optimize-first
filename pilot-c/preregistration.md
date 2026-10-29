# Pilot-c pre-registration: the comparison-based set, the matched correction, and the band's calibration

Written 2026-10-29, before any run of pilot-c, from `proposal.md`, section 13 (the revisions the user approved after the re-pilot's close call; the pass rule written by the agent and not separately reviewed). Committed alone, so that its timestamp precedes every file in `pilot-c/results/`. Everything not stated here is as in `pilot-b/preregistration.md` and its amendment.

## 1. The three questions

1. Does the problem exist (as in the re-pilot)?
2. Is it large enough to matter at 250 per group (as in the re-pilot)?
3. Is there a fix: does the correction with 20 imputations per resample remove at least half of the optimism, and is there one construction, bootstrap or hybrid, whose band is calibrated with and without imputation and whose comparison-based set holds the best threshold while being narrower than the band-based set?

## 2. The procedures

Notation as in `pilot-b/preregistration.md`. $L = 20$ imputations for the analysis.

**Grid.** $K = 41$ equally spaced thresholds between the 10% and 90% quantiles of the completed values, all 20 completed datasets together (the observed values in the null cell). The target of a set is the grid's best threshold, $k^* = \arg\max_k J(c_k)$, with $J$ the true curve.

**Resamples for the curve.** $R_B = 1{,}000$ resamples within each disease group, each imputed $M = 2$ times; $\hat J_{b1}$, $\hat J_{b2}$, and their mean $\bar J_b$ on the grid. $V$ is the $K \times K$ covariance of $\bar J_b$ over resamples; $W = R_B^{-1}\sum_b (\hat J_{b1} - \hat J_{b2})(\hat J_{b1} - \hat J_{b2})^\top / 2$ is the within-resample covariance of single imputations; the covariance of the 20-imputation estimate is $\Sigma = V - W/M + W/L$, with negative eigenvalues set to zero. $\mathrm{SE}_k = \sqrt{\Sigma_{kk}}$ and $\mathrm{SE}_{jk} = \sqrt{\Sigma_{jj} + \Sigma_{kk} - 2\Sigma_{jk}}$.

**Bands**, each $\bar J(c_k) \pm q\,\mathrm{SE}_k$:

- bootstrap: $q$ is the 95% quantile over resamples of $\max_k \lvert \bar J_b(c_k) - m_k \rvert / \sqrt{V_{kk}}$, $m$ the mean of $\bar J_b$ (the re-pilot's construction, with 1,000 resamples);
- hybrid: $q$ is the 95% quantile of $\max_k \lvert Z_k \rvert / \mathrm{SE}_k$ over 5,000 draws of $Z \sim N(0, \Sigma)$;
- Rubin's rules and the pointwise intervals: as in the re-pilot, from the 20 imputations.

**Band-based set** of a band: $\{k : U_k \ge \max_j L_j\}$ (the re-pilot's).

**Comparison-based set** of a construction: $\{k : \bar J(c_j) - \bar J(c_k) \le q_D\,\mathrm{SE}_{jk} \text{ for every } j \ne k\}$. Its critical value is $q_D = \max_k q_k$, where $q_k$ is the 95% quantile of $\max_{j \ne k} \{(D_j - D_k) / s_{jk}\}$ (one-sided; pairs with $s_{jk} = 0$ left out): for the bootstrap construction $D = \bar J_b - m$ over resamples with $s_{jk}$ from $V$; for the hybrid construction $D = Z \sim N(0, \Sigma)$ over 5,000 draws with $s_{jk} = \mathrm{SE}_{jk}$. If, for $k = k^*$, every comparison $\bar J(c_j) - \bar J(c_{k^*}) - \{J(c_j) - J(c_{k^*})\} \le q_D \mathrm{SE}_{jk^*}$ holds, then $k^*$ is in the set, because $J(c_j) - J(c_{k^*}) \le 0$. A set's length is its number of grid points times the grid step.

**Optimism correction.** Primary: 100 further resamples, each imputed 20 times; $o_b = \bar J_b(\hat c_b) - \bar J(\hat c_b)$ as in the re-pilot's amendment; the corrected index is $\bar J(\hat c) - \overline{o}$. Secondary: the same from the first 200 of the curve's resamples with 2 imputations (the re-pilot's).

**Reference.** The length of the true near-optimal region $\{c : J(c) \ge J^* - 0.01\}$, from the closed form.

## 3. Design

Sharp shape ($\delta = 2$, $\sigma_1 = 1$), 250 per group, the empirical estimator, five cells: 1, no missing values (null); 2, 40% missing, predictive mean matching (base); 3, 40%, normal imputation (normal twin); 4, 60%, predictive mean matching; 5, 60%, normal imputation. Missingness intercepts as before.

**Replicates, blocks, and seeds.** $R = 2{,}000$ per cell, run in blocks of 100 replicates; block $b$ of cell $k$ uses the L'Ecuyer-CMRG generator seeded with $20261030 + 1000k + b$, so that results do not depend on which worker runs a block. Seven PSOCK workers (the user's allowance for pilot-c, against the three of `rules.md`), the BLAS pinned to one thread, one block per task.

**Time box.** One hour on seven workers. Ten replicates of every cell are timed first; if 2,000 replicates per cell do not fit, $R$ is lowered to the largest multiple of 100 that fits, recorded in `pilot-c/decisions.md`; the pass rule is unchanged.

**Measures per cell**, each with its MCSE: the optimism of the apparent index and its bias against $J^*$; the bias against $J(\hat c)$ of the 20-imputation and the 2-imputation corrected indices, and the ratio of the former's to the optimism; the simultaneous coverage and mean half-width of the pointwise, Rubin's-rules, bootstrap, and hybrid bands; the coverage of $k^*$ and the mean length of the band-based and comparison-based sets of the bootstrap and hybrid constructions; the critical values; the share of replicates whose grid contains $c^*$; the realized missing fraction; for the note, the pooling-order gap and the cutoff's RMSE ratio.

## 4. Known-answer checks

Saved by `pilot-c/pilot.R` to `pilot-c/results/known_answers.rds` before the run, and asserted by the tests:

- the comparison critical value for two independent coordinates: $\Phi^{-1}(0.95)$;
- the hybrid band's critical value for 41 independent coordinates: $\Phi^{-1}\{(1 + 0.95^{1/41})/2\}$;
- the covariance split on synthetic resamples with known sampling and imputation covariances: $\Sigma = \Sigma_s + \Sigma_w / L$ (an off-diagonal entry and a diagonal entry);
- a comparison-based set built on the true curve with positive standard errors contains the best grid threshold;
- the optimism of a reproducing bootstrap with 20 imputations per resample: exactly zero;
- the true near-optimal region's length against a separate root-finding computation.

From the run: the pooling-order gap is exactly zero in every replicate of the null cell.

## 5. The pass rule, with numbers

Base cell: cell 2. Normal twin: cell 3. Null cell: cell 1. 60% cell: cell 4. Met: the point estimate on the passing side. Near: within three MCSE of the threshold.

1. **Q1 passes** if in the base cell the mean optimism exceeds 3 MCSE, and the pointwise intervals' simultaneous coverage is below 0.90.
2. **Q2 passes** if the mean optimism is at least 0.01 in the base cell or the 60% cell.
3. **Q3 passes** if (a) in the base cell and the normal twin, $\lvert$mean of the 20-imputation corrected index $- J(\hat c)\rvert \le 0.5 \times$ the mean optimism; and (b) at least one construction (bootstrap, hybrid) passes all of: its band's simultaneous coverage in $[0.93, 0.97]$ in the null cell, the base cell, and the normal twin; its comparison-based set contains $k^*$ in at least 0.93 of replicates in the base cell and the normal twin; and the set's mean length is at most 0.75 of the same construction's band-based set's mean length in the base cell and the normal twin (judged on the ratio of means, with its MCSE by the delta method).

The status: `piloted-fail` if Q1 fails, or Q3 fails with no deciding estimate near its threshold; `piloted-pass` if all three pass and no deciding estimate is near; `piloted-close-call` otherwise, stated both ways. For Q3: when it is met, it is near if a clause of (a) is near or every passing construction has a near clause; when it is not met, it is near if every failed clause of (a) is near and at least one construction has only near clauses among its failed ones.

## 6. Reported whatever the outcome

Every cell with every measure and its MCSE, both constructions beside each other, the 2-imputation correction beside the 20-imputation one, the 60% cells, the known-answer checks, the timing and the runtime, and any deviation from this file, marked.
