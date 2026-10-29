# Project spec: Pool first or optimize first? Cutoffs from multiply imputed biomarker data

| | |
|---|---|
| Proposal | `proposal.md`, final 2026-10-28, re-scoped 2026-10-29 (section 12) |
| Authors | as in `DESCRIPTION` |
| Written | 2026-10-28; rewritten for the re-scope 2026-10-29 |
| Status | draft 2026-10-28 |

## 1. Question and why it matters

**Question (one sentence):** When a biomarker is missing at random and multiply imputed, do a simultaneous band for the pooled Youden curve, the set of thresholds the band cannot separate from the best one, and a bootstrap-then-impute correction of the reported index give the curve's uncertainty at the nominal rate and an index that does not overstate the accuracy of the chosen cutoff?

**Why it matters:** An analyst who imputes a missing marker and reports an optimal cutoff reports an index that overstates the cutoff's accuracy, by about two points of the Youden index at 250 per group in the first pilot, and no interval for the curve or the cutoff, because no method for either exists under imputation. If the procedure works, the analyst reports the pooled curve with its band, the near-optimal thresholds, and a corrected index; the order of pooling, which the first pilot showed changes the index by less than half a point, becomes a closed-form note.

## 2. Mechanism we suspect

The reported index is the maximum of a noisy curve, so it sits above the true accuracy of the threshold it picks: the maximum rewards the threshold where sampling noise happened to push the curve up. With $J(c) = F_0(c) - F_1(c)$, the pooled curve $\bar J$ of $L$ completed datasets, its maximizer $\hat c$, and its maximum $\max_c \bar J(c)$, the optimism is $\max_c \bar J(c) - J(\hat c) \ge 0$ in expectation; it is present without any missing data (Fluss, Faraggi, and Reiser 2005 report the empirical method's poor performance) and imputation adds the pooling-order gap $\kappa \hat B_c / 2$ on top of it for an analyst who optimizes first. A bootstrap that repeats the whole analysis, imputation included, estimates that optimism if the resample's maximum relates to the original curve as the original maximum relates to $J$; for a cube-root estimator the standard bootstrap is inconsistent (Cattaneo, Jansson, and Nagasawa 2020), so the correction may remove only part of it. For the curve itself, $\bar J(c)$ at a fixed $c$ is an average of differences of proportions, regular, so a band built from Rubin's rules (the binomial covariance of the empirical curve within imputations plus the covariance of the curves between imputations) or from bootstrap-then-impute should cover $J$ over a range of thresholds at the nominal rate when the imputations are proper and unbiased. When the imputations are biased, as predictive mean matching was where donors are sparse in the first pilot, no variance method restores coverage, which is why the correctly specified normal imputation is in the design. If the band covers, the near-optimal set $\{c : U(c) \ge \max_{c'} L(c')\}$ contains $c^*$, because $U(c^*) \ge J^* \ge J(c') \ge L(c')$ for every $c'$.

## 3. Pilot

Filled twice: the plan when the spec is written, the answers after the verdict (stage 2, step 5). The first pilot (`pilot/`, `piloted-fail`) and its answers are in `pilot/pilot-report.html`; this section is the re-pilot's.

**Code:** `pilot-b/pilot.R`, run from the project root with `Rscript pilot-b/pilot.R`; it calls the functions in `R/` (the first pilot's, plus the curve on a grid, the two bands, the near-optimal set, the optimism correction, and the normal imputation). `pilot-b/verdict.R` applies the pass rule to the saved summaries.

**Pass rule:** from `proposal.md`, section 12, made exact in `pilot-b/preregistration.md`. The base cell is the sharp symmetric peak, 40% missing, 250 per group, predictive mean matching, $L = 20$, the empirical estimator.

1. The problem exists if, in the base cell, the apparent index exceeds the true accuracy of the chosen cutoff by more than three Monte Carlo standard errors, and the pointwise Rubin's intervals read as a band cover $J$ over the grid in less than 0.90 of replicates.
2. It is large enough if the apparent index's optimism is at least 0.01 in the base cell or in its 60% twin.
3. There is a fix if (a) the corrected index's absolute bias against the true accuracy of the chosen cutoff is at most half the apparent index's in the base cell; (b) the bootstrap-then-impute band covers $J$ over the grid in 0.92 to 0.98 of the base cell's replicates for both engines; and (c) its near-optimal set contains $c^*$ in at least 0.92 of the base cell's replicates for both engines.

**Verdict file:** `pilot-b/results/verdict.rds` (with `pilot-b/results/verdict.csv`), written by `pilot-b/verdict.R` after the run.

**Plot:** `pilot-b/results/coverage-by-cell.png`, the simultaneous coverage of each band in every cell, written by `pilot-b/verdict.R`.

**The three pilot answers:** status `piloted-close-call`, by the pre-registered rule, from `pilot-b/results/verdict.rds`; 500 replicates per cell, run label `pilot`.

1. Does the effect exist? Yes. In the base cell the reported index exceeds the true accuracy of the chosen cutoff by 0.0261 (MCSE 0.0017), and the pointwise Rubin's intervals read as a band contain the true curve at all 41 thresholds in 0.414 (MCSE 0.022) of replicates.
2. Is it large enough to matter at realistic sample sizes? Yes: the optimism is 0.0261 in the base cell and 0.0301 (MCSE 0.0022) with 60% missing, above 0.01.
3. Is there an obvious fix or diagnostic? Partly. The bootstrap-then-impute correction leaves a bias of 0.15 (MCSE 0.06) of the optimism in the base cell, and its near-optimal set contains $c^*$ in 1.000 of replicates with both engines. The bootstrap-then-impute band covers in 0.910 (MCSE 0.013) of replicates with predictive mean matching, below and near the 0.92 limit, and in 0.944 (MCSE 0.010) with normal imputation.

## 4. ADEMP skeleton

This becomes `protocol.md` at the design stop of stage 3.

**Aims.**

1. Do the Rubin's-rules and the bootstrap-then-impute bands cover the Youden curve over a range of thresholds at 95%, and does the near-optimal set derived from each contain the optimal cutoff at least as often, across shapes, sizes, missing fractions, and imputation engines?
2. Does the bootstrap-then-impute optimism correction remove the overstatement of the reported index, against the true accuracy of the chosen cutoff and against the maximum of the curve?
3. As a closed-form note: how large is the pooling-order gap against $\kappa B_c / 2$, and is the averaged cutoff more accurate than the pooled argmax? For a discrete covariate (Aim 3 of the proposal), do the procedures recover the stratum-specific and the population-optimal cutoffs?

**Data-generating mechanisms.**

- Factors varied, with levels: the peak shape (sharp symmetric, flat asymmetric, two near-equal maxima); the missing fraction (0%, 20%, 40%, 60%); the sample size per group (100, 250, 1,000); the strength of the auxiliary; the imputation engine (predictive mean matching, normal linear regression, the nearest-neighbour method of Long, Zhang, and Hsu 2011 with several auxiliaries); the within-dataset estimator (empirical, Gaussian kernel); the number of bootstrap resamples and imputations per resample; for Aim 3, two to four strata with the prevalence ratio varied.
- Factors fixed, and why: missingness at random through the auxiliary and the disease status, because the claims are made under that assumption; the disease status always observed (verification bias is a different paper); equal group sizes in the base design, with one unbalanced arm at fixed total size.
- A cell where the answer is known: 0% missing, where the bands are complete-data bands and the pooling-order gap is exactly zero; a noiseless curve, whose optimism is zero; independent grid points, where the sup-t critical value has a closed form.

**Estimands.** The Youden curve $J(c)$ over a range of thresholds; its maximizer $c^*$ and maximum $J^*$; the true accuracy $J(\hat c)$ of a chosen threshold and the regret $J^* - J(\hat c)$; for Aim 3, $c_{\mathrm{cs}}(v)$ and $c_{\mathrm{pop}}(v)$.

**Methods compared.** For the curve: pointwise Rubin's intervals (the default), the Rubin's-rules sup-t band, the bootstrap-then-impute sup-t band, and impute-then-bootstrap; the near-optimal set from each band; for the index: the apparent pooled maximum, the bootstrap-then-impute optimism-corrected index, and the complete-data intervals of Bantis, Nakas, and Reiser (2019) on the complete cases; for the cutoff: pool first, optimize then mean, optimize then median, and the bagged cutoff of Zhang et al. (2020).

**Performance measures.** Simultaneous coverage and mean half-width of each band; coverage of $c^*$ by each near-optimal set and its mean length; bias of each index against $J(\hat c)$ and against $J^*$; bias, empirical standard error, and root mean squared error of the cutoff and the regret; the pooling-order gap against its closed form. No method in the design is a hypothesis test, so no power cells are planned; if a test is added, its power cells follow `workflow/rules.md`, section 3.

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
- Cutoff criteria other than the Youden index and its population-weighted form of Aim 3: a natural sequel, parked.
- A theory of the bootstrap for cube-root estimators under imputation (for example a subsampling or modified-bootstrap correction in the manner of Cattaneo, Jansson, and Nagasawa 2020): if the re-pilot shows the plain correction falls short, that theory is a separate paper, parked.
- A software paper or a CRAN release: the package `micutoff` is the compendium's byproduct.
- A reporting checklist for applied users: a separate applied note, parked.

## 9. Reading

1. Bartlett and Hughes 2020. After reading, a reader can answer: why does imputing and then bootstrapping give invalid variances under uncongeniality, and which bootstrap-then-impute variants stay valid?
2. Fluss, Faraggi, and Reiser 2005. After reading, a reader can answer: which complete-data estimator of the Youden index has the worst performance, and in which direction is the empirical index biased?
3. Long, Zhang, and Hsu 2011. After reading, a reader can answer: how are the imputed datasets combined into one ROC curve, and what is reported for the uncertainty of the threshold the paper calls the unanimous optimum?
