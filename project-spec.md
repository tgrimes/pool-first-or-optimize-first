# Project spec: Pool first or optimize first? Cutoffs from multiply imputed biomarker data

| | |
|---|---|
| Proposal | `proposal.md`, final 2026-10-28 |
| Authors | as in `DESCRIPTION` |
| Written | 2026-10-28 |
| Status | draft 2026-10-28 |

## 1. Question and why it matters

**Question (one sentence):** When a biomarker is missing at random and multiply imputed, does maximizing the Youden curve in each completed dataset and averaging (optimize first) report a larger index than maximizing the averaged curve (pool first), by about half the curvature times the between-imputation variance of the cutoffs, and can the cutoff, its index, and their uncertainty be reported from the pooled curve instead?

**Why it matters:** An analyst who imputes a missing marker and reports an optimal cutoff picks one of the two orders, and published papers that do this leave the order unstated (Abdulrahman et al. 2022; Atlantis et al. 2016). If the orders differ, the analyst reads the index off the pooled curve, which removes an overstatement that more imputations do not shrink. The analyst also reports a band for the curve and a set of near-optimal thresholds in place of an interval for the cutoff, because Rubin's rules cannot supply an interval for an argmax.

## 2. Mechanism we suspect

The mean of the per-dataset maxima is never below the maximum of the mean curve, because each completed dataset has its own accuracy curve and its maximum sits where that curve happened to be high. Write the true Youden curve as $J(c) = F_0(c) - F_1(c)$, with $F_d$ the distribution function of the marker $X$ in group $D = d$, its maximizer $c^*$, and its maximum $J^*$. With $L$ completed curves $\hat J_l$ whose maximizers are $\hat c_l$, the optimize-first index is $L^{-1}\sum_l \max_c \hat J_l(c)$ and the pool-first index is $\max_c \bar J(c)$ with $\bar J = L^{-1}\sum_l \hat J_l$. The first is at least the second in every dataset. If each curve is quadratic near its peak with curvature $\kappa_l$, the gap is exactly

$$
\frac{1}{L}\sum_{l=1}^{L} \frac{\kappa_l}{2}\,(\hat c_l - \tilde c)^2,
\qquad \tilde c = \frac{\sum_l \kappa_l \hat c_l}{\sum_l \kappa_l},
$$

which is about $\kappa \hat B_c / 2$ with equal curvatures, $\hat B_c$ being the spread of the $\hat c_l$ across imputations. $\hat B_c$ estimates the between-imputation variance of the cutoff given the observed data, which does not fall as $L$ grows. So the gap shrinks with the sample size and not with the number of imputations. A third-order term $\tau = J'''(c^*)$ moves the pool-first cutoff away from the mean of the $\hat c_l$ by about $\tau \hat B_c / (2\kappa)$, which is zero for a symmetric peak. The gap is zero when nothing is missing (every completed dataset is the same) and large when the cutoffs scatter across imputations: high missingness near $c^*$, a weak auxiliary, a flat peak. For the empirical curve, a step function with no curvature, the cutoff is a cube-root estimator (Kim and Pollard 1990) and the gap should be positive and of order $n^{-2/3}$ rather than $\kappa \hat B_c / 2$. If the mechanism is wrong, the gap does not track $\hat B_c$ across replicates, or it shrinks as $L$ grows.

## 3. Pilot

Filled twice: the plan when the spec is written, the answers after the verdict (stage 2, step 5).

**Code:** `pilot/pilot.R`, run from the project root with `Rscript pilot/pilot.R`; it calls the functions in `R/` (data generation, the two imputation engines, the two curve estimators, the three pooling rules, the cell summaries). `pilot/verdict.R` applies the pass rule to the saved summaries.

**Pass rule:** from the proposal, section 7, made exact in `pilot/preregistration.md`. The base cell is the sharp symmetric peak, 40% missing, 250 per group, the empirical estimator, predictive mean matching, $L = 20$. The rules are judged on the predictive-mean-matching cells; the nearest-neighbour cells are reported beside them.

1. The effect exists if the mean optimize-first minus pool-first difference in the reported index is positive by more than three Monte Carlo standard errors in the base cell, and the difference is exactly zero in every replicate of the 0%-missing cell.
2. It is large enough if that mean difference is at least 0.01 in the base cell for at least one estimator, or at least 0.02 in the 60% cell, or the root mean squared error of the cutoff differs between the two orders by at least 10% in some cell. Otherwise Aim 1 is a negative result and the weight moves to Aim 2: the close-call outcome.
3. There is a fix and a diagnostic if (a) the absolute bias of the pool-first index against $J^*$ is at most half of the optimize-first one in the base cell, both beyond three Monte Carlo standard errors; (b) the correlation between $\hat B_c$ and the difference across the base cell's replicates is at least 0.5, and for the kernel estimator the ratio of the mean difference to the mean of $\kappa \hat B_c / 2$ lies between 0.5 and 2; and (c) the pointwise 95% Rubin's-rules interval for $J(c^*)$ from the kernel curves contains the true value in 92% to 98% of the base cell's replicates.

**Verdict file:** `pilot/results/verdict.rds` (with `pilot/results/verdict.csv`), written by `pilot/verdict.R` after the run.

**Plot:** `pilot/results/gap-by-cell.png`, the mean difference in the reported index with its Monte Carlo error in every cell, written by `pilot/verdict.R`.

**The three pilot answers:** status `piloted-fail`, by the pre-registered rule, from `pilot/results/verdict.rds`; 500 replicates per cell, run label `pilot`.

1. Does the effect exist? Yes. In the base cell the mean optimize-first minus pool-first difference in the index is 0.0028 (MCSE 0.0001), and it is exactly zero in all 500 replicates of the null cell.
2. Is it large enough to matter at realistic sample sizes? Not as a difference in the index: the base cell's mean difference is 0.0028 for the empirical and 0.0007 for the kernel estimator, and the largest in any predictive-mean-matching cell is 0.0049 (60% missing, 250 per group, empirical), below the 0.01 and 0.02 thresholds and below the 0.005 negative-result line. The rule passes through its third clause: the root mean squared error of the cutoff is lower for optimize first, a ratio of 0.80 (MCSE 0.02) to pool first in the base cell.
3. Is there an obvious fix or diagnostic? A diagnostic, yes: the correlation of $\hat B_c$ with the difference is 0.65 (MCSE 0.03), the kernel ratio to $\kappa \hat B_c / 2$ is 0.84 (MCSE 0.02), and the kernel interval for $J(c^*)$ covers in 0.932 (MCSE 0.011) of replicates, near the 0.92 limit. A fix, no: the pool-first index is biased upward by 0.0190 and the optimize-first index by 0.0218, a ratio of 0.87 (MCSE 0.01) against the required 0.5.

## 4. ADEMP skeleton

This becomes `protocol.md` at the design stop of stage 3.

**Aims.**

1. Does the optimize-first index exceed the pool-first index by $\kappa B_c / 2$ for smooth curves and by an amount of order $n^{-2/3}$ for the empirical curve, without shrinking as $L$ grows? Which of the pooling rules (pool first; optimize then mean; optimize then median; optimize then vote for a discrete marker) has the smallest error in the cutoff and the smallest regret?
2. Do the pointwise and simultaneous bands for $J(c)$, the near-optimal set of thresholds, and the regret bound reach their nominal coverage under Rubin's rules, impute-then-bootstrap, and bootstrap-then-impute?
3. For a discrete covariate $V$, how far apart are the stratum-specific and the population-optimal cutoffs, and do the pooled procedures recover each?

**Data-generating mechanisms.**

- Factors varied, with levels: the peak shape (sharp symmetric and flat asymmetric binormal, plus a shape with two near-equal maxima for the consistency question); the missing fraction (0%, 20%, 40%, 60%); the sample size per group (100, 250, 1,000, 4,000); the strength of the auxiliary (within-group correlation with the marker from weak to strong); the imputation engine (predictive mean matching, the nearest-neighbour method of Long, Zhang, and Hsu 2011); $L$ (5, 20, 100); the within-dataset estimator (empirical, Gaussian kernel, Box-Cox binormal); for Aim 3, two to four strata with the prevalence ratio varied.
- Factors fixed, and why: missingness at random through the auxiliary and the disease status, because the paper's claims are made under that assumption; the disease status always observed, because a missing status is the verification-bias problem, a different paper; equal group sizes in the base design, with one unbalanced arm at fixed total, because the stacking lemma and the gap formula are stated for fixed group sizes.
- A cell where the answer is known: 0% missing, where every pooling rule gives the same cutoff and the gap is exactly zero; the sharp binormal cell, with $c^* = 1$ and $J^* = 2\Phi(1) - 1$; synthetic quadratic curves, where the gap equals the formula exactly; for Aim 3, normal strata with a common variance, where $c_{\mathrm{pop}}(v) - c_{\mathrm{cs}}(v) = \sigma^2 \log\{w_0(v)/w_1(v)\} / \{\mu_1(v) - \mu_0(v)\}$.

**Estimands.** The Youden curve $J(c) = F_0(c) - F_1(c)$ at each threshold; its maximizer $c^*$ and maximum $J^*$; the true accuracy $J(\hat c)$ of a chosen threshold and its regret $J^* - J(\hat c)$; for Aim 3, $c_{\mathrm{cs}}(v)$ and $c_{\mathrm{pop}}(v)$.

**Methods compared.** Pool first (argmax of $\bar J$); optimize then mean; optimize then median; optimize then vote (discrete marker only); for each, the empirical, kernel (Gaussian, Silverman's bandwidth per group), and Box-Cox binormal curves; for inference, pointwise Rubin's rules with the binomial within-imputation variance, a sup-t band by bootstrap-then-impute, impute-then-bootstrap, the complete-data intervals of Bantis, Nakas, and Reiser (2019) on the complete cases, and the bagged cutoff of Zhang et al. (2020); predictive mean matching from `mice` with 5 donors and the nearest-neighbour method with $K = 3$ and its bootstrap step.

**Performance measures.** Bias, empirical standard error, and root mean squared error of the cutoff; bias of the reported index against $J^*$; the true accuracy of the chosen cutoff and the regret; the optimize-first minus pool-first gap against $\kappa \hat B_c / 2$; coverage and width of the pointwise and simultaneous bands; coverage of $c^*$ by the near-optimal set. No method in the design is a hypothesis test, so no power cells are planned; if a test is added (for example a test that the two orders agree), its power cells follow `workflow/rules.md`, section 3.

**Replicates and Monte Carlo SE target.** [TO CONFIRM: 2,000 replicates per cell in the production run, which gives a Monte Carlo standard error of about 0.005 for a coverage near 0.95; idea.md planned 1,000, which gives about 0.007]{.tc}

## 5. Application

**Dataset:** NHANES 2013-2014, 2015-2016, and 2017-2018 pooled: the serum cotinine (`COT_H`, `COT_I`, `COT_J`), smoking questionnaire (`SMQ_H`, `SMQ_I`, `SMQ_J`), and demographics (`DEMO_H`, `DEMO_I`, `DEMO_J`) files from `wwwn.cdc.gov/Nchs/Data/Nhanes/Public/YEAR/DataFiles/` (YEAR 2013, 2015, 2017), downloaded by `analysis/00_download.R` into `data/raw/`. The documentation pages of all three cycles give the same laboratory method (isotope-dilution high-performance liquid chromatography with tandem mass spectrometry) and the same lower limit of detection, 0.015 ng/mL (read 2026-10-28), so the three cycles are pooled with the cycle as an auxiliary.

**Comparison:** adults with a smoking answer, current smokers against everyone else, on the log scale of serum cotinine in ng/mL; race/ethnicity as the discrete covariate of Aim 3; the counts per group and the share with cotinine missing, by cycle, are in `pilot/results/nhanes_summary.rds`.

**What to show:** on adults with observed cotinine and a smoking answer, with missingness imposed at random given age, sex, education, income, cycle, and race/ethnicity at 20 to 60%, the pool-first and optimize-first cutoffs fall inside one near-optimal set while the optimize-first index exceeds the pool-first index by the amount $\kappa \hat B_c / 2$ predicts, with the full-data cutoff as the benchmark; by race/ethnicity, the stratum-specific and population-optimal cutoffs differ in the direction the prevalence ratio sets.

## 6. Target journal

**Target journal:** Statistical Methods in Medical Research: room for three aims and the simulation, the home of the imputation order-of-operations papers, no charge.

**Fallback:** Biometrical Journal: the home of the cutoff-inference papers, the same readers; switching costs moving Aim 3 and the derivations to the supplement to meet 4,500 words and rewriting the abstract; the single-anonymized review lets the repository link stay open.

Target's limit and AI policy: around 8,000 words; "AI chatbots, for example ChatGPT, should not be listed as authors"; generative use that affects methods, analysis, or results is disclosed at submission in the Methods or Acknowledgements.

## 7. Milestones

[TO CONFIRM: the dates below spread the eight months of idea.md from 2026-10-28; no deadline was given at stage 1]{.tc}

| Stage | Ends with | Due |
|---|---|---|
| 2. Pilot | `pilot/pilot-report.html`, the verdict file, `pilot/decisions.md` | 2026-10-29 |
| 3. Manuscript, design stop | `protocol.md` from the approved design | 2026-12-31 |
| 3. Manuscript, first draft | `manuscript/manuscript.html` in draft mode | 2027-04-30 |
| 3. Manuscript, settled | the draft after the revision rounds | 2027-05-31 |
| 4. Background report | `background/background.html` | 2027-06-11 |
| 5. Mock review | the last `review/round-N/` | 2027-06-25 |
| Submission | the final render and the checker in final mode | 2027-06-30 |

## 8. Out of scope

The project must not add:

- A second application dataset: ADNI and the Pima data were set aside at stage 1.
- A continuous covariate for Aim 3: Aim 3 is restricted to a discrete covariate (stage 1).
- Missing disease status (the verification-bias problem) or missingness not at random: each is its own paper.
- Cutoff criteria other than the Youden index and its population-weighted form of Aim 3 (closest to the top-left corner, equal sensitivity and specificity, cost-weighted): a natural sequel, parked.
- A theory result beyond the closed-form gap, the stacking lemma, the binormal stratum gap, and the Youden case of the cube-root limit in the supplement: the limit law of the gap under imputation is a separate theory paper, parked.
- A software paper or a CRAN release: the package `micutoff` is the compendium's byproduct.
- A reporting checklist for applied users (`idea.md` lists one): a separate applied note, parked.

## 9. Reading

1. Long, Zhang, and Hsu 2011. After reading, a reader can answer: how are the imputed datasets combined into one ROC curve, and what is reported for the uncertainty of the threshold the paper calls the unanimous optimum?
2. Leyrat et al. 2019. After reading, a reader can answer: why are propensity scores averaged across imputations not balancing scores, and what plays the role of that argument for a cutoff?
3. Fluss, Faraggi, and Reiser 2005. After reading, a reader can answer: which complete-data estimator of the Youden index has the largest bias, and in which direction?
