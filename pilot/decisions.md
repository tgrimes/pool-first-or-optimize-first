# Decisions log: the pilot

Each decision says what was decided, the alternatives, why, what the user should check, and the file that holds its numbers. The process log (what was read, the timing, the run) is `log/02-pilot.md`; the pre-registration is `pilot/preregistration.md`, committed before any run.

## D0. The literature pass

The prior work is the proposal's section 5 (`proposal.md`), with 38 sources in Zotero and their passages in `manuscript/citations.csv`. Read since the proposal: the imputation algorithm of Long, Zhang, and Hsu (2011), sections 2.3 to 2.5 and 3, through the Zotero connector, to implement their nearest-neighbour method (D5); the NHANES documentation of `COT_H`, `COT_I`, and `COT_J` (laboratory method and limit of detection, the same in the three cycles), of `DEMO_J`, and of `SMQ_H` and `SMQ_J` (variable codes). No new literature search was made; stage 2 has no search budget.

## D1. The status call

The status is `piloted-fail`, by the pre-registered rule (`pilot/preregistration.md`, section 5), applied by `pilot/verdict.R` (`pilot/results/verdict.rds`). Question 1 passes, question 2 passes through its third clause only, and question 3 fails on its clause (a), far from the threshold; a failed question 3 with no deciding estimate near its threshold is a fail.

The reading that fails, the rule's: the pooling order changes the reported index by less than half a point of the Youden index in every predictive-mean-matching cell, below the proposal's own negative-result line of 0.005; pooling first removes about an eighth of the index's overstatement in the base cell, not half; and for the empirical curve the optimize-first cutoff is the more accurate one. Aim 1 as proposed, that pooling first is the right order and the difference matters, is not supported, and question 2 passes only because the cutoffs differ in accuracy in the direction that favours optimizing first.

The reading that passes: the mechanism is confirmed in every respect the pilot could test. The gap exists in every cell with missing values, is exactly zero without them, tracks the spread of the cutoffs, matches the closed form for the kernel curve once the pooled curve's own curvature is used, and does not shrink as $L$ grows. Question 3(a)'s threshold presumed that the gap is most of the index's upward bias; the pilot shows that most of it is the ordinary optimism of a maximum, present without any missing data, which Aim 2's selection-corrected index is meant to remove. Read this way the project is re-scoped rather than dropped: Aim 2 (inference and the optimism correction under imputation) leads, the pooling-order result becomes a closed-form note, and two findings the proposal did not anticipate join it: averaging the per-dataset cutoffs is more accurate than the pooled argmax for the step curve, and pointwise Rubin's-rules intervals undercover badly at 60% missing.

What the user should check: the numbers behind both readings in `pilot/results/verdict.csv` and `pilot/results/cell_summaries.csv`, and whether a re-scope (a revised proposal and a re-pilot in `pilot-b/`) or a drop follows.

## D2. Both estimators on the same completed datasets

What: each replicate imputes once and applies the empirical and the kernel estimator to the same completed datasets, so the proposal's 42 cells are 21 data cells with two analyses each, plus the kernel analysis of the two extra-$L$ cells (22 data cells, 44 analysis cells). Alternatives: separate datasets per estimator (twice the imputation time, unpaired comparisons). Why: the estimators are compared on paired data and the run takes half the time. Check: that the two extra kernel cells, reported as secondary, are wanted. File: `pilot/results/cell_summaries.rds`.

## D3. Predictive mean matching through `mice.impute.pmm()`

What: each imputation calls the univariate predictive-mean-matching function of `mice` (5 donors, type 1 matching, predictors $D$, $Z$, $D \times Z$) rather than `mice()`. Alternatives: `mice()` with `maxit = 1`. Why: only the marker is missing and the predictors are complete, so the univariate step is the whole algorithm, and the per-call overhead of `mice()` is avoided. Check: whether the production run should call `mice()` itself so that the code reads as an analyst's. File: `R/impute.R`.

## D4. The empirical cutoff's convention

What: the empirical curve is constant between consecutive observed values; the cutoff is the midpoint of the maximizing interval, and when several intervals tie at the maximum, the mean of their midpoints. Alternatives: the smallest maximizer (the convention of the argmax theory of Seijo and Sen 2011), or the observed value at the left end. Why: the rule is symmetric, so in the sharp cell with equal group sizes the full-data cutoff is unbiased for $c^* = 1$ exactly, which makes the null cell a known-answer check; ties are frequent because the index takes values on a lattice of step $1/n$. Check: the null cells' cutoff bias in `pilot/results/cell_summaries.rds`.

## D5. The nearest-neighbour engine

What: MIB-2 of Long, Zhang, and Hsu (2011): the prediction model (linear regression of $X$ on $D$, $Z$, $D \times Z$ among observed subjects) and the propensity model (logistic regression of the observed indicator on the same terms) refit on a bootstrap sample of all subjects before each imputation; both linear predictors standardized over all subjects; distance weights 0.5 and 0.5; the 3 nearest observed subjects with the same $D$, one drawn at random. Alternatives: draw donors from the bootstrap sample rather than the original data; fit the models separately within $D$. Why: the paper imputes "the missing X in the original data set" after refitting on the bootstrap sample, and fits one model with $D$ and its interactions. Consequence: with one auxiliary both scores are linear in $Z$ within a group, so the donors are the 3 nearest in $Z$ whatever the bootstrap draw, as the paper's section 2.4 says; the between-imputation spread comes only from the random draw among 3 donors. Check: the known-answer row on the donors in `pilot/results/known_answers.rds`.

## D6. The kernel curve's maximizer

What: bandwidth by Silverman's rule (`stats::bw.nrd0()`) per group and per completed dataset; each curve and the averaged curve searched on 201 points between the 0.5% and 99.5% quantiles of the observed marker, then refined by `optimize()`. Alternatives: one bandwidth for all completed datasets, which makes the stacked kernel curve equal to the averaged one. Why: a per-dataset bandwidth is what an analyst running the analysis in each completed dataset gets. Check: whether Aims 1 and 2 should also report the common-bandwidth version. File: `R/curves.R`.

## D7. An average that is exact for identical inputs

What: every average over imputations is computed as $v_1 + L^{-1}\sum_l (v_l - v_1)$. Why: in the null cells the 20 completed datasets are identical, and an ordinary floating-point mean of 20 equal numbers can differ from them in the last bit, which would make the pre-registered "exactly zero" fail for a reason unrelated to the method. Check: the null cells' `gap_n_nonzero` column in `pilot/results/cell_summaries.rds`.

## D8. The predicted gap uses the true curvature

What: the predicted gap is $\kappa \hat B_c / 2$ with $\kappa$ the population curvature of the shape and $\hat B_c$ the spread of that replicate's cutoffs with divisor $L$; the version with the pooled kernel curve's own curvature $\hat\kappa$ is reported as secondary. Why: the pass rule tests the formula, so its ingredients other than $\hat B_c$ are held at their known values. Check: the two ratios, `gap_ratio` and `gap_ratio_hat`, in `pilot/results/cell_summaries.rds`.

## D9. Rubin's rules for $J(c)$

What: the within-imputation variance is the binomial formula of each group's proportion, also for the kernel curve; the degrees of freedom are Rubin's large-sample formula. Alternatives: the Barnard-Rubin small-sample degrees of freedom (identical here, with infinite complete-data degrees of freedom); a kernel-specific variance. Why: the proposal fixes the binomial within-imputation variance. Check: the kernel coverage in the null cells, where imputation plays no part, against the coverage with missing values. File: `pilot/results/cell_summaries.rds`.

## D10. Readings of the pass rule

The pre-registration states five readings where the proposal left a case open: thresholds are judged on the point estimate, and an answer within three MCSE of its threshold is "near"; the 60% clause of question 2 applies to either estimator; a largest gap between 0.005 and 0.01 is the same outcome as one below 0.005; question 3(b)'s ratio is a ratio of means; the three answers combine into the status by the rule in its section 5. Check: that these readings match the intent of the proposal's section 7. File: `pilot/preregistration.md`, section 5; applied by `ApplyPassRule()` in `R/verdict.R`.

## D11. The replicate count

What: 500 replicates per data cell, as pre-registered. Before the run, ten replicates of every one of the 22 data cells were timed on two workers (the pre-registration asked for the costliest cells only; timing all of them gives the projection directly), and the run was projected by scheduling the cells longest first on three workers. Alternatives: fewer replicates, if the projection had exceeded the one-hour box. Why: the projection for 500 replicates is within the box. Check: the per-cell timings and the projection in `pilot/results/timing.rds`, and the actual runtime in `pilot/results/run_info.rds`.

## D12. The application's data

What: the nine NHANES files were downloaded with the user's approval and are not committed; the adult cohort is everyone aged 18 and over who answered whether they smoked 100 cigarettes, a current smoker being one who now smokes every day or some days; the description uses no survey weights and no imputation; the full-data curve is computed on log cotinine standardized by the nonsmokers' mean and standard deviation, so that its curvature is on the simulation's scale. Alternatives: Benowitz et al.'s or Tompkins et al.'s exact smoker definitions, which the passages read do not give. Check: the smoker definition before stage 3. File: `pilot/results/nhanes_summary.rds`.

## What was not done

- The checks in the proposal's section 4 that need more sizes or shapes: the error of the cutoff at 100 and 4,000 per group, the quantile plots of the scaled cutoff, the discrete marker and the vote (P4), the shape with two near-equal maxima, and the Box-Cox binormal estimator. They belong to the full design (`project-spec.md`, section 4).
- Aim 2's inference beyond the pointwise interval: the simultaneous band, the near-optimal set, the regret bound, and the bootstrap variance methods.
- The application: the NHANES cohort was downloaded and described, but no missingness was imposed and nothing was imputed; the survey weights were not used.
- More than one auxiliary, an unbalanced design, and a misspecified imputation model.
- The production replicate count, which the spec leaves to the user.
