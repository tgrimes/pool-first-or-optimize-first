# Pilot pre-registration: pool first or optimize first

Written 2026-10-28, before any run, from `proposal.md` (final 2026-10-28), section 7, and the stage 1 decisions D15 (both imputation engines, rules judged on predictive mean matching) and D16 (the 0.01 threshold). Committed alone, so that its timestamp precedes every file in `pilot/results/`. Where the proposal left a case open, the reading used is stated here and marked "reading" so that it can be checked.

## 1. The three questions

1. Does the effect exist: is the index reported by optimizing in each completed dataset and averaging (P2) larger than the maximum of the averaged curve (P1)?
2. Is it large enough to matter at realistic sizes (250 and 1,000 per group)?
3. Is there a fix or a diagnostic: does P1 remove most of the bias, does the between-imputation spread of the cutoffs predict the gap, and do pointwise Rubin's-rules intervals for $J(c)$ cover?

## 2. Notation

$J(c) = F_0(c) - F_1(c)$, a subject being called positive when $X > c$; $c^* = \arg\max_c J(c)$; $J^* = J(c^*)$; $\kappa = -J''(c^*)$; $\tau = J'''(c^*)$. In one replicate, $\hat J_l$ is the curve of the $l$-th completed dataset, $\hat c_l$ its maximizer, $\bar J = L^{-1} \sum_l \hat J_l$, and $\hat B_c = L^{-1} \sum_l (\hat c_l - \bar c)^2$ with $\bar c$ the mean of the $\hat c_l$ (divisor $L$, so that the quadratic identity holds exactly).

The pooling rules, each giving a cutoff and a reported index:

- P1, pool first: cutoff $\arg\max_c \bar J(c)$, index $\max_c \bar J(c)$.
- P2, optimize then mean: cutoff $\bar c$, index $L^{-1} \sum_l \max_c \hat J_l(c)$.
- P3, optimize then median: cutoff the median of the $\hat c_l$, index $\bar J$ at that cutoff (as in `idea.md`).

The gap is $G = $ P2 index $-$ P1 index, never negative. Its predicted value is $\kappa \hat B_c / 2$, with $\kappa$ the true curvature of the cell's shape. The predicted cutoff difference P1 $-$ P2 is $\tau \hat B_c / (2\kappa)$.

## 3. Design of the first simulation

**Data.** In group $D = 0$, $X \sim N(0, 1)$; in group $D = 1$, $X \sim N(\delta, \sigma_1^2)$; $n$ subjects per group. The auxiliary is $Z = X + e$ with $e \sim N(0, 1)$. $X$ is missing with probability $\mathrm{expit}(\alpha_0 + 1.0\,Z + 0.5\,D)$, with $\alpha_0$ solved numerically so that the expected missing fraction over both groups is the target.

| Factor | Levels | Reason |
|---|---|---|
| Shape | sharp symmetric: $\delta = 2$, $\sigma_1 = 1$ ($c^* = 1$, $J^* = 0.6827$, $\kappa = 0.484$, $\tau = 0$); flat asymmetric: $\delta = 1.5$, $\sigma_1 = 2.5$ ($c^* \approx 1.355$, $J^* \approx 0.435$, $\kappa \approx 0.220$, $\tau \approx 0.159$), each computed numerically by `MarkerTruth()` | curvature and asymmetry are what the gap and the cutoff difference depend on |
| Missing fraction | 0% (null), 40% (base), 60% | the gap is zero at 0% and grows with the spread of the imputed values |
| $n$ per group | 250 (base), 1,000 | a clinical-study size and an NHANES-cycle size |
| Imputation engine | predictive mean matching: `mice::mice.impute.pmm()`, 5 donors, type 1 matching, predictors $D$, $Z$, $D \times Z$; nearest neighbours (MIB-2 of Long, Zhang, and Hsu 2011): prediction score from a linear regression of $X$ on $D$, $Z$, $D \times Z$ among observed subjects, propensity score from a logistic regression of the observed indicator on $D$, $Z$, $D \times Z$, both standardized over all subjects, weights 0.5 and 0.5, $K = 3$ nearest observed subjects with the same $D$, one drawn at random, both models refit on a bootstrap sample of all subjects before each imputation | the default an analyst uses, and the method of the paper the idea starts from (stop 1 of stage 1) |
| $L$ | 20; also 5 and 100 in the base cell, predictive mean matching only | the gap should not shrink with $L$ |
| Estimator | empirical; Gaussian-kernel distribution functions with Silverman's bandwidth (`stats::bw.nrd0()`) per group and per completed dataset | the non-regular and the regular case |
| Pooling | P1, P2, P3 in every replicate | |

Reading: the two estimators are applied to the same completed datasets in each replicate, so a data cell (shape, missing fraction, $n$, engine, $L$) yields two analysis cells, one per estimator, and the estimators are compared on paired data. The proposal's 42 cells are 21 data cells; the kernel analysis of the two extra-$L$ data cells comes at no extra simulation and is reported as secondary, for 22 data cells and 44 analysis cells. In the 0% cells there is nothing to impute: the full data are copied $L = 20$ times and passed through the same pooling code, so that the null cell tests that code.

**Empirical curve and its maximizer.** $\hat J_l$ is evaluated at the sorted distinct values $u_1 < \dots < u_m$ of the union of the completed datasets (all imputed values are observed values, so this is the set of observed values), where it is constant on $[u_k, u_{k+1})$. The maximizing intervals are those whose value is within $10^{-12}$ of the maximum; the cutoff is the mean of their midpoints $(u_k + u_{k+1})/2$. The mean of the midpoints is symmetric, so in the sharp cell with equal group sizes the full-data cutoff is unbiased for $c^* = 1$ exactly.

**Kernel curve and its maximizer.** $\hat F_d(c) = n_d^{-1} \sum_i \Phi\{(c - X_i)/h_d\}$. Each curve and $\bar J$ are evaluated on 201 equally spaced points between the 0.5% and 99.5% quantiles of the observed $X$; the maximum is refined by `stats::optimize()` between the neighbours of the best grid point (tolerance $10^{-8}$).

**Averages across imputations.** Every average over $l$ (the curve $\bar J$, the P2 cutoff, the P2 index) is computed as $v_1 + L^{-1} \sum_l (v_l - v_1)$, which equals the ordinary mean and is exact when the $v_l$ are identical, so that the null cell's gap is exactly zero in floating point.

**Pointwise Rubin's-rules interval for $J(c)$**, at $c = c^*$ and $c^* \pm 0.5$: $Q_l = \hat J_l(c)$, $U_l = \hat F_{0l}(c)\{1 - \hat F_{0l}(c)\}/n + \hat F_{1l}(c)\{1 - \hat F_{1l}(c)\}/n$, $\bar Q$, $\bar U$, $B = (L-1)^{-1} \sum_l (Q_l - \bar Q)^2$, $T = \bar U + (1 + L^{-1}) B$, degrees of freedom $\nu = (L-1)\{1 + \bar U / ((1 + L^{-1}) B)\}^2$ (infinite when $B = 0$), interval $\bar Q \pm t_{\nu, 0.975} \sqrt{T}$. Covered when it contains the true $J(c)$.

**Measures per analysis cell**, each with its Monte Carlo standard error (MCSE):

- bias and root mean squared error of the cutoff under P1, P2, P3 (MCSE of a root mean squared error by the delta method);
- the reported index minus $J^*$ under each rule;
- the true $J$ at each rule's cutoff, and the regret $J^* - J(\hat c)$;
- the mean gap $\bar G$, its minimum over replicates, the mean of $\kappa \hat B_c / 2$, their ratio of means (MCSE by the delta method), and the correlation of $\hat B_c$ with $G$ across replicates (MCSE $(1 - r^2)/\sqrt{R - 3}$);
- the mean cutoff difference P1 $-$ P2 against the mean of $\tau \hat B_c / (2\kappa)$;
- coverage of the pointwise interval at $c^*$ and $c^* \pm 0.5$ (MCSE $\sqrt{p(1-p)/R}$);
- the ratio of root mean squared errors of the cutoff, P2 over P1 (MCSE by the delta method on the paired squared errors);
- the realized missing fraction.

Secondary, with no pass rule: the gap at 1,000 per group over the gap at 250 per group, against $4^{-2/3} = 0.40$ for the empirical and $4^{-1} = 0.25$ for the kernel estimator; the ratio of the gap to $\hat\kappa \hat B_c / 2$ with $\hat\kappa$ the curvature of the pooled kernel curve at its maximum, which an analyst could compute.

**Replicates and seeds.** $R = 500$ per data cell (MCSE of a coverage near 0.95: 0.010), 11,000 simulated datasets. The design table numbers the data cells 1 to 22; cell $k$ uses the L'Ecuyer-CMRG generator seeded with $20261028 + k$ and runs its replicates in order, so a cell's results do not depend on which worker runs it. Three PSOCK workers, the BLAS pinned to one thread in each.

**Time box.** One hour of compute on three cores. Before the run, ten replicates of the costliest cells (60% missing, 1,000 per group, each engine; the $L = 100$ cell) are timed. If the projected run exceeds one hour, $R$ is lowered to the largest multiple of 100 that fits, and the change is recorded in `pilot/decisions.md`; the pass rule is unchanged.

## 4. Cells with a known answer

These run as tests in `tests/testthat/` before the pilot, and the null and sharp cells are also read from the pilot's own output.

- The 0% cells: P1, P2, and P3 give the same cutoff, and $G = 0$ exactly, in every replicate.
- The sharp cell at 0% missing and 1,000 per group: the mean cutoff of each estimator is within three MCSE of $c^* = 1$ (exact by symmetry); the true $J^* = 2\Phi(1) - 1$.
- Synthetic quadratic curves with unequal curvatures: the P1 cutoff equals $\sum_l \kappa_l \hat c_l / \sum_l \kappa_l$ and the gap equals the formula of section 2, to $10^{-10}$.
- Synthetic cubic curves with common $\kappa$ and $\tau$: the P1 $-$ P2 cutoff difference matches $\tau \hat B_c / (2\kappa)$ to first order (relative error shrinking with $\hat B_c$).
- The Jensen inequality: on random curves, $G \ge 0$.
- The kernel distribution function with a fixed bandwidth on normal data: its mean over many samples matches $\Phi(c/\sqrt{1 + h^2})$.
- The stacking lemma: the empirical curve of the stacked completed datasets equals $\bar J$ to machine precision.
- The nearest-neighbour engine with one auxiliary: its donors are the $K$ nearest observed subjects in $Z$ within the same group (a literal implementation).
- The missingness intercept: the simulated missing fraction matches the target within three MCSE.

## 5. The pass rule, with numbers

The base cell is: sharp, 40% missing, 250 per group, predictive mean matching, $L = 20$, empirical estimator. Its kernel twin is the same data cell with the kernel estimator. The 60% cell is the base cell with 60% missing. All rules are judged on the predictive-mean-matching cells; the nearest-neighbour cells are reported beside them and decide nothing.

A threshold is met when the point estimate is on the passing side. An answer is near its threshold when the estimate is within three MCSE of it.

1. **Q1 passes** if $\bar G > 3$ MCSE in the base cell, and $G = 0$ in all 500 replicates of the null cell with the base cell's shape, size, and estimator. A nonzero $G$ in any null cell is a bug, and the run stops for it.
2. **Q2 passes** if any of: (a) $\bar G \ge 0.01$ in the base cell or its kernel twin; (b) $\bar G \ge 0.02$ in the 60% cell for either estimator (reading: the proposal names no estimator for this clause); (c) the ratio of root mean squared errors of the cutoff, P2 over P1, is at least 1.10 or at most 0.90 in some predictive-mean-matching cell with missing values (both estimators, both shapes, both sizes, all three values of $L$). If none holds, Aim 1 is a negative result and the weight moves to Aim 2. The proposal names that outcome "close call" when $\bar G < 0.005$ in every such cell; reading: the same outcome applies when the largest $\bar G$ lies between 0.005 and 0.01, and the report says which of the two it is.
3. **Q3 passes** if all of: (a) in the base cell, $|\text{P1 index bias}| \le 0.5\,|\text{P2 index bias}|$, with both biases beyond three MCSE from zero; (b) in the base cell, the correlation of $\hat B_c$ with $G$ is at least 0.5, and in the kernel twin the ratio $\bar G / \overline{\kappa \hat B_c / 2}$ lies in $[0.5, 2]$; (c) in the kernel twin, the coverage of the pointwise interval for $J(c^*)$ lies in $[0.92, 0.98]$.

The status (reading: the proposal gives the three rules and not how they combine):

- `piloted-fail` if Q1 fails, or Q3 fails with no deciding estimate near its threshold.
- `piloted-pass` if Q1, Q2, and Q3 pass and no deciding estimate is near its threshold.
- `piloted-close-call` otherwise: Q2 does not pass while Q1 and Q3 do (the proposal's close call), or the answer that decides the status has an estimate near its threshold. For a rule met through one of several clauses (Q2), the answer is near only if every clause that is met is near; for a rule that needs all its clauses (Q3), it is near if any clause that decides it is near. A close call is stated both ways.

`pilot/verdict.R` applies these rules to `pilot/results/cell_summaries.rds` and writes the table to `pilot/results/verdict.rds` and `.csv`.

## 6. Reported whatever the outcome

Every analysis cell with every measure and its MCSE, the nearest-neighbour cells beside the predictive-mean-matching ones, the null cells, the secondary measures, the outcomes of the known-answer tests, the timing run and the total runtime, the realized missing fractions, and any deviation from this file, marked as such.
