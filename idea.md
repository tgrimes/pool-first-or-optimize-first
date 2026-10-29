# Pool First or Optimize First? Optimal Cutoffs from Multiply Imputed Biomarker Data

Oct 28, 2026 · Tyler · Live version: https://claude.ai/artifact/F8CcXrNULGtQMUdGEKF5td

## Summary

We propose to establish how an optimal biomarker cutoff should be estimated and reported when the biomarker is multiply imputed. The core question is whether to pool the accuracy curves across imputations and then pick the cutoff (pool first), or pick a cutoff in each imputed dataset and then combine them (optimize first).

The paper will (1) derive when the two orders agree and how they differ, including an upward bias in the Youden index under optimize-first; (2) argue that an interval for the cutoff c\* is usually the wrong summary, and replace it with a pooled confidence band for the whole J(c) curve and a near-optimal set of cutoffs; and (3) extend both ideas to a simple covariate-specific setting with a discrete covariate, contrasting the covariate-specific Youden cutoff with the population-optimal covariate-dependent rule.

We evaluate everything by simulation, building on the nonparametric multiple imputation of Long, Zhang & Hsu (2011), and apply it to serum cotinine in NHANES and to CSF biomarkers in ADNI.

## Background and motivation

There is no accepted method for choosing a cutoff from multiply imputed data, even though multiple imputation (MI) is the standard way to handle a missing biomarker. Long, Zhang & Hsu (2011) proposed nonparametric MI for ROC analysis when the biomarker is missing at random. They impute using nearest neighbours on prediction and propensity scores (doubly robust), with a bootstrap step that makes Rubin's rules valid for the AUC.

They also chose an optimal EPDS cutoff for depression in pregnancy. They averaged sensitivity + specificity at each threshold across imputations and took the maximum, reporting "16 for all methods" with no measure of uncertainty. That choice of pooling order was made without discussion. No paper we found compares it with the alternatives.

Three observations motivate the work:

- **The order of operations matters elsewhere in MI.** In propensity-score analysis, pooling scores first versus pooling effects ("Across" vs "Within") changes bias and coverage (Mitra & Reiter 2016; Leyrat et al. 2017; Granger et al. 2019).
- **The cutoff is a non-regular estimand.** The empirical Youden cutoff is an argmax of a step function: slow convergence, non-normal limit, unreliable bootstrap. Rubin's rules assume the opposite.
- **Cutoff uncertainty is already poorly handled with complete data.** Cutoff CIs are wide and rarely reported (Thiele & Hirschfeld 2023). Interval methods exist (Fluss et al. 2005; Bantis et al. 2018) but none address MI.

Recent work gives Youden-index intervals when disease status is missing (Wang et al. 2025; Jia et al. 2026). The case of a missing biomarker under MI, and covariate-specific cutoffs with a missing biomarker, appear unaddressed.

## Specific aims

The paper has two primary aims and one secondary aim. Aim 1 carries the paper.

1. **Aim 1 (primary): Pool first or optimize first.** Compare four pooling rules for the optimal cutoff and the Youden index across imputations, analytically and by simulation. Identify when they agree, quantify the optimize-first bias in J, and give a recommendation.
2. **Aim 2 (primary): Inference that respects the decision.** Replace the cutoff CI with a pooled confidence band for J(c), a near-optimal set of cutoffs, and the regret J(c\*) − J(ĉ). Compare variance methods: Rubin's rules (pointwise), bootstrap-then-impute and impute-then-bootstrap.
3. **Aim 3 (secondary): A simple covariate-specific extension.** With a discrete covariate V (2 to 4 levels), apply Aims 1 and 2 to the covariate-specific Youden cutoff and to the population-optimal covariate-dependent rule. Show how far apart the two targets are.

**Scope decision.** We recommend keeping Aim 3, restricted to a discrete V. With discrete V both targets reduce to (weighted) Youden problems within strata, so the Aim 1 and 2 machinery carries over almost unchanged. It costs one simulation arm and one analysis per dataset. It also makes the paper more useful, because cotinine cutoffs are already known to differ by race/ethnicity. Continuous V and the attenuation bias of score-based imputation are deferred to a follow-up paper. If length becomes a problem, Aim 3 moves to the supplement and keeps one main-text figure.

## Setup, estimands and pooling rules

X is the biomarker (missing for some subjects), D the disease status (always observed), Z the auxiliary variables (always observed), and δ = 1 when X is observed. We assume missing at random: δ is independent of X given (D, Z). Imputation produces L completed datasets, l = 1, …, L.

The population targets are the Youden curve, the optimal cutoff and the Youden index:

```latex
J(c) = \Pr(X > c \mid D = 1) + \Pr(X \le c \mid D = 0) - 1, \qquad c^* = \arg\max_c J(c), \qquad J^* = J(c^*)
```

In imputed dataset l, Ĵ_l(c) is computed with one of three within-dataset estimators: empirical (step function), kernel-smoothed, or binormal after a Box-Cox transform.

| Rule | Cutoff reported | Youden index reported |
| --- | --- | --- |
| P1 Pool then optimize | argmax of the averaged curve J̄(c) = mean_l Ĵ_l(c) | J̄(ĉ) |
| P2 Optimize then mean | mean of ĉ_l = argmax Ĵ_l | mean of Ĵ_l(ĉ_l) |
| P3 Optimize then median | median of ĉ_l | J̄ at that cutoff |
| P4 Optimize then vote (discrete X) | most frequent ĉ_l | J̄ at that cutoff |

Stacking the L datasets and running one ROC analysis is not a separate rule. Disease status is observed, so every imputed dataset has the same group sizes, and the stacked empirical (or fixed-bandwidth kernel) curve equals J̄(c) exactly. Stacking therefore coincides with P1, unless the bandwidth is re-chosen on the stacked data. Showing this is a one-line lemma in the paper.

P2 is what most applied analysts would do by default ("run the analysis in each dataset, then combine"). P1 is what Long et al. did.

## Theoretical work

The expected headline: for smooth curves, P1 and P2 give nearly the same cutoff but different Youden indices. P2's index is biased upward by about half the curvature times the between-imputation variance of the cutoffs. For step-function and discrete curves, the two rules can also disagree on the cutoff itself.

1. **Jensen gap (exact, any L).** For any curves, the mean of the per-imputation maxima is at least the maximum of the mean curve. So the Youden index reported under P2 is never smaller than under P1.
2. **Local quadratic approximation.** Suppose near the peak Ĵ_l(c) ≈ M_l − (κ_l / 2)(c − ĉ_l)². Then P1's cutoff is the curvature-weighted mean of the ĉ_l, which equals P2's when curvatures are equal. The gap in J is shown below. It does not shrink as L grows, only as n grows.
3. **Consistency.** If each Ĵ_l converges uniformly to J and c\* is a unique, well-separated maximum, P1 to P4 are all consistent (argmax continuous mapping). For nearest-neighbour imputation, this needs observed donors near c\*. That is a positivity-type condition we will state explicitly.
4. **Non-regularity of the cutoff.** The empirical ĉ_l converges at about the n^(1/3) rate to a non-normal limit, so Rubin's rules for ĉ have no justification. For smoothed estimators the cutoff is approximately normal, and Rubin's rules may be adequate. J(c) at fixed c is a difference of proportions and is regular, so pointwise Rubin's rules apply.
5. **Discrete markers.** With a unique maximum on a lattice, the chance of picking the wrong cutoff decays quickly in n, so the vote (P4) is natural. P2 leaves the lattice (e.g. 15.6). The vote share is a ready-made stability diagnostic.

```latex
\frac{1}{L}\sum_{l} \max_c \hat J_l(c) \;-\; \max_c \bar J(c) \;\approx\; \frac{1}{L}\sum_{l} \frac{\kappa_l}{2}\,(\hat c_l - \tilde c)^2, \qquad \tilde c = \frac{\sum_l \kappa_l \hat c_l}{\sum_l \kappa_l}
```

A conjecture for simulation to test: with empirical curves, P1 also reduces the ordinary "maximum of a noisy curve" optimism. Averaging over imputations smooths the imputed part of the noise before the maximum is taken.

## Inference: report the curve, not just the argmax

The paper's position is that a CI for c\* is well defined but usually answers the wrong question. Its width mainly reflects how flat J is near the peak, not how much accuracy is at stake. It also depends on the arbitrary equal weighting in Youden's criterion, and it is statistically awkward. We will state when a CI for c\* is still the right tool: checking a guideline cutoff, comparing populations, or planning sample size.

The paper will report four quantities instead.

1. **Pooled band for J(c).** At each c on a grid, apply Rubin's rules to Ĵ_l(c) using the binomial within-imputation variance, giving pointwise intervals. For a simultaneous band, use a sup-t critical value from bootstrap-then-impute.
2. **Near-optimal set.** Define Δ(c) = J(c) − J\*. Report every c whose upper confidence bound for Δ(c) reaches 0. Working with the difference uses the strong correlation between neighbouring cutoffs, so the set is tighter than comparing two separate bands. Hypothetical example: EPDS {14, 15, 16, 17}.
3. **Regret.** A confidence bound for J\* − J(ĉ): how much accuracy is plausibly lost by using the estimated cutoff.
4. **Selection-corrected sensitivity and specificity at ĉ.** Bootstrap optimism correction: choose the cutoff in each bootstrap sample, evaluate it on the original data, and repeat inside the MI loop.

Variance methods to compare:

| Method | Valid under uncongeniality? | Cost | Use in paper |
| --- | --- | --- | --- |
| Rubin's rules, pointwise J(c) | Needs proper imputation (MIB-2) | Low | Primary for pointwise bands |
| Impute then bootstrap | Generally no (Bartlett & Hughes) | Medium | Comparator |
| Bootstrap then impute (few imputations per resample) | Yes | High | Primary for simultaneous band, near-optimal set, regret |
| Rubin's rules on the cutoff ĉ (smoothed only) | Approximate | Low | Comparator, to show what a c\* interval misses |

This reframing also makes the pooling problem tractable. At any fixed c, J(c) is regular, so nothing non-regular is ever pooled.

## Covariate-specific extension (discrete V)

With a discrete covariate V, both covariate-dependent targets reduce to a Youden problem within each stratum. The only difference is the weights, so Aims 1 and 2 carry over directly. V is part of Z and always observed; it is the variable the cutoff is allowed to depend on (e.g. race/ethnicity, APOE4 status).

- **Covariate-specific Youden cutoff.** In each stratum, c_cs(v) maximizes J(c | v) = Se(c | v) + Sp(c | v) − 1. Equivalently, flag a subject when their risk exceeds the prevalence *in their stratum*.
- **Population-optimal rule.** Choose one cutoff per stratum to maximize overall sensitivity + specificity. Overall Se is a weighted average of stratum sensitivities with weights w₁(v) = P(V = v | D = 1), and likewise for Sp with w₀(v). The problem separates by stratum into a weighted Youden criterion. Equivalently, flag a subject when their risk exceeds the *overall* prevalence.

```latex
c_{\mathrm{cs}}(v) = \arg\max_c \big[\mathrm{Se}(c\mid v) + \mathrm{Sp}(c\mid v)\big], \qquad c_{\mathrm{pop}}(v) = \arg\max_c \big[w_1(v)\,\mathrm{Se}(c\mid v) + w_0(v)\,\mathrm{Sp}(c\mid v)\big]
```

The two coincide when V is independent of D. Under a binormal model with common variance σ² in stratum v, the gap has a closed form, which we will use to size the simulation scenarios:

```latex
c_{\mathrm{pop}}(v) - c_{\mathrm{cs}}(v) = \frac{\sigma^2 \log\{w_0(v)/w_1(v)\}}{\mu_1(v) - \mu_0(v)}
```

Practical points:

- The weights w₀ and w₁ depend only on (V, D), which are fully observed, so they need no imputation.
- Imputation must respect strata. Working models include V and D × V, and nearest-neighbour donors are matched exactly on V. This avoids the attenuation of covariate effects that a single mean score could cause (deferred to the follow-up paper).
- Pooling rules P1 to P4, bands and near-optimal sets are applied per stratum.
- We also report what covariate dependence buys: the overall J of each covariate-dependent rule minus the J of one common cutoff.

## Simulation study

The simulations build on Long et al.'s design (five Gaussian auxiliaries; X linear or log-linear in Z; Gaussian or skewed errors) and add the factors that matter for cutoffs: peak shape, discreteness, and donor sparsity near c\*.

| Factor | Levels |
| --- | --- |
| Sample size per group (n₀ = n₁) | 100, 250, 1000 |
| Shape of J near c\* | Sharp peak; flat peak; two near-equal local maxima (mixture in the diseased group) |
| Marker scale | Continuous; discrete 0–30 (EPDS-like rounding) |
| Missing fraction | 20%, 40%, 60% |
| MAR mechanism | Weak; strong; concentrated among high X via Z (few donors near c\*) |
| Imputation | MIB-2 (Long et al.); predictive mean matching (mice); parametric normal (mice); plus complete-case and full-data references |
| Number of imputations L | 5, 20, 100 |
| Within-dataset estimator | Empirical; kernel-smoothed; Box-Cox binormal |
| Pooling rule | P1, P2, P3, P4 (P4 for discrete only) |
| Aim 3 arm | V with 3 levels; odds ratio between V and D of 1, 2, 4; stratum-specific location shifts |

**Performance measures:**

- bias and RMSE of ĉ and of the reported J;
- the true accuracy achieved, J(ĉ), and the regret J\* − J(ĉ);
- coverage of pointwise and simultaneous J(c) bands;
- whether the near-optimal set contains c\*, and how large the set is;
- for discrete markers, P(ĉ = c\*);
- for Aim 3, the same measures per stratum, plus the gap between c_pop(v) and c_cs(v).

**Compute budget:** 1,000 replications per scenario. The full factorial is too large, so the main grid fixes L = 20 and varies one factor at a time from a base case, with a 2×2 interaction check for missing fraction × peak shape. Bootstrap-then-impute (200 resamples × 2 imputations) runs only on a subset of about 12 scenarios.

## Data applications

The primary application is serum cotinine for smoking status in NHANES. It is public, large, and has a published race/ethnicity-specific cutoff analysis we can revisit. ADNI is the secondary application, with substantial real missingness.

| Dataset | Biomarker X | Reference D | Covariate V | Auxiliaries Z | Missingness | Access |
| --- | --- | --- | --- | --- | --- | --- |
| **NHANES** (primary) | Serum cotinine (log scale) | Self-reported current cigarette smoking | Race/ethnicity (3 to 4 groups); sex as a sensitivity check | Age, sex, education, income, household smokers, survey cycle | Real: cotinine absent for interviewed participants without a usable blood sample (rate to verify). Supplemented by plasmode MAR amputation at 20 to 60% | Public download; free |
| **ADNI** (secondary) | CSF Aβ42, p-tau181, or their ratio | Baseline clinical diagnosis (AD vs cognitively normal) | APOE ε4 carrier status | Age, education, MMSE, ADAS-Cog, CDR-SB, hippocampal volume, FDG-PET | Real: CSF only for participants who had a lumbar puncture (roughly half in ADNI-1; to verify) | Free; data use application required |
| Pima Indians Diabetes (backup, teaching) | Serum insulin | Diabetes by WHO criteria | Age group | Glucose, BMI, age, pregnancies, pedigree | Real: about 49% of insulin values missing (to verify) | Public (mlbench R package); see caveat below |

**Why NHANES cotinine fits Aim 3.** Benowitz et al. (2009) analysed 3,078 smokers and 13,078 nonsmokers from NHANES 1999–2004. Their optimal adult cutoffs differed by race/ethnicity: 5.92 ng/mL (non-Hispanic Black), 4.85 (non-Hispanic White) and 0.84 (Mexican American), against 3.08 overall. Tompkins et al. (2019) repeated this in NHANES 2009–2014 (13,357 adults, cutoff 3.63 ng/mL). Neither paper handled missing cotinine, reported uncertainty for the cutoffs, or distinguished c_cs(v) from c_pop(v). Smoking prevalence differs by race/ethnicity, so the two targets should differ noticeably.

**Plasmode design.** Starting from complete cotinine cases, we impose known MAR missingness through the auxiliaries. The full-data cutoff then serves as a known benchmark, which makes the real-data application partly verifiable.

Caveats to address:

- Self-reported smoking is an imperfect reference standard. This is standard in this literature; it will be stated as a limitation.
- NHANES is a complex survey. The main analysis is unweighted, as a methods illustration. A weighted sensitivity analysis is optional.
- The Pima dataset raises Indigenous data-governance concerns. Use it only for teaching or code examples, if at all.
- The original EPDS data from Long et al. are not public. We could ask the authors for access to reproduce their cutoff analysis directly.

## Deliverables, timeline and risks

The target is one methods paper (e.g. *Statistics in Medicine* or *Biometrical Journal*) plus an R package, in about eight months.

![Plan: 5 phases over about 8 months, 3 gates](proposal-timeline.png)

| Months | Phase | Work |
| --- | --- | --- |
| 1–2 | Theory and code | Jensen gap, quadratic approximation, stacking lemma; R code for MIB-2 and P1–P4 |
| 2–4 | Simulation study (Aims 1–2) | Pooling rules × estimators × variance methods across peak shapes, missingness and L |
| | *Gate* | Do P1 and P2 differ in practice? This sets the emphasis |
| 4–5 | Aim 3 and NHANES | Discrete-V simulation arm; NHANES cotinine by race/ethnicity, real and plasmode |
| | *Gate* | ADNI data access approved (else NHANES only) |
| 5–6 | ADNI application | CSF biomarkers vs diagnosis with real lumbar-puncture missingness; APOE ε4 strata |
| | *Gate* | Length check: Aim 3 in main text or supplement |
| 7–8 | Writing and package release | Draft, internal review, submission; R package and NHANES scripts released |

The simulation results gate everything after them: they decide whether the paper leads with the pooling comparison or with inference.

Deliverables:

- [ ] Paper: theory (Jensen gap, quadratic approximation, stacking lemma, binormal c_pop − c_cs gap), simulation study, two data applications
- [ ] R package: Long et al. MIB-2 imputation; pooling rules P1–P4; pooled J(c) bands; near-optimal sets; regret; stratified c_cs and c_pop
- [ ] Reproducible NHANES analysis scripts (public data)
- [ ] Short applied note for users: a recommended reporting checklist for cutoffs from imputed data

| Risk | Likelihood | Fallback |
| --- | --- | --- |
| P1 and P2 barely differ in realistic scenarios | Medium | That is itself a result. The paper's weight shifts to inference (Aim 2) and the J bias, which differs by construction |
| Bootstrap-then-impute is too slow at scale | Medium | Few imputations per resample (von Hippel & Bartlett style); fewer scenarios; cluster computing |
| Little real missingness in NHANES cotinine | Medium | Plasmode amputation is the primary NHANES analysis; ADNI carries the real-missingness example |
| ADNI access delayed | Low | Proceed with NHANES only; ADNI moves to a follow-up |
| Paper too long with Aim 3 | Medium | Aim 3 moves to the supplement with one main-text figure |
| Simultaneous band theory for MI is hard | Medium | Report pointwise bands with Rubin's rules; use the bootstrap for the near-optimal set only |

## References

Links go to the paper's DOI or its Consensus record.

**Imputation and ROC**

- Long, Zhang & Hsu (2011). [Nonparametric multiple imputation for ROC analysis when some biomarker values are missing at random](https://doi.org/10.1002/sim.4338). *Stat Med* 30:3149–3161.
- Long, Hsu & Li (2012). [Doubly robust nonparametric multiple imputation for ignorable missing data](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3280694/). *Statistica Sinica* 22:149–172.

**Youden index and cutoffs**

- Fluss, Faraggi & Reiser (2005). [Estimation of the Youden index and its associated cutoff point](https://consensus.app/papers/details/4551569ceb5a5b86ac126ea040f33efa/). *Biometrical Journal*.
- Bantis, Nakas & Reiser (2018). [Confidence intervals for the maximum of the Youden index and the corresponding cutoff point](https://consensus.app/papers/details/f3baba12aa1555dfa5e77c0cfca88ae9/). *Biometrical Journal*.
- Yin et al. (2016). [Improved nonparametric estimation of the optimal diagnostic cut-off point associated with the Youden index](https://consensus.app/papers/details/f58f0ec1cdbd52448771911e243dd61e/). *Biometrical Journal*.
- Thiele & Hirschfeld (2023). [Confidence intervals and sample size planning for optimal cutpoints](https://consensus.app/papers/details/aea63307ee4152b2bad2044137939c41/). *PLOS ONE*.
- Wang et al. (2025). [Interval estimation for the Youden index of a continuous diagnostic test with verification biased data](https://consensus.app/papers/details/0dae4ab29da55c519bd8eb0ebcd10ed1/). *Stat Methods Med Res*.
- Jia et al. (2026). [Confidence intervals on partial Youden index under verification bias](https://consensus.app/papers/details/3e879ad2a41e56cbaa95a707d870547b/). *Pharmaceutical Statistics*.

**Combining MI with the bootstrap and with propensity scores**

- Schomaker & Heumann (2018). [Bootstrap inference when using multiple imputation](https://consensus.app/papers/details/3c3e24a6da21599195e12db0292a5b00/). *Stat Med*.
- Bartlett & Hughes (2020). [Bootstrap inference for multiple imputation under uncongeniality and misspecification](https://consensus.app/papers/details/2d46dd63ece55f0a9226af0c9ad5ba0d/). *Stat Methods Med Res*.
- Granger et al. (2019). [Avoiding pitfalls when combining multiple imputation and propensity scores](https://consensus.app/papers/details/11237ef072c75e01aaa162322688582b/). *Stat Med*.
- Leyrat et al. (2017). [Propensity score analysis with partially observed covariates](https://consensus.app/papers/details/92a994f7fa155b0b851f724af081f11d/). *Stat Methods Med Res*.
- Mitra & Reiter (2016). [A comparison of two methods of estimating propensity scores after multiple imputation](https://consensus.app/papers/details/5ca9edacc1d9540d8b77a043dde28b2d/). *Stat Methods Med Res*.
- von Hippel & Bartlett (2021). [Maximum likelihood multiple imputation: faster imputations and consistent standard errors without posterior draws](https://consensus.app/papers/details/f9c759189b5350948a6b1e16df617731/). *Statistical Science*. Implemented in the bootImpute and mlmi R packages.

**Covariate-specific ROC**

- Inácio de Carvalho, de Carvalho & Branscum (2017). [Nonparametric Bayesian covariate-adjusted estimation of the Youden index](https://consensus.app/papers/details/7719cb6c0e735714a479b0a32e201f1d/). *Biometrics*.
- Rodríguez-Álvarez & Inácio (2021). [ROCnReg](https://consensus.app/papers/details/a952a38cfc6c57279f1a6533fd7a91f1/). *R Journal*.

**Data applications**

- Benowitz et al. (2009). [Optimal serum cotinine levels for distinguishing cigarette smokers and nonsmokers within different racial/ethnic groups](https://consensus.app/papers/details/8a5c093c834e5a29918f3413d4962f54/). *Am J Epidemiol*.
- Tompkins et al. (2019). [Differentiating between smokers and nonsmokers using serum cotinine](https://consensus.app/papers/details/05a718c38f9a5b3f9628bbd61c5a0d6b/). *Biomarkers in Medicine*.
- Li et al. (2015). [Covariate-specific time-dependent ROC curves in the presence of missing biomarkers](https://consensus.app/papers/details/5497b7d81a8253c7a281a4e125ac8f3a/). *Biometrics* (uses ADNI with missing biomarkers).
