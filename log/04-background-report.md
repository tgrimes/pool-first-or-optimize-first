# Stage 4 log: background report

Workflow 0.2.3 at the start, 0.2.4 from 12:37 (`workflow/04-background-report.md`, `workflow/rules.md`). Started 2026-10-29 at 12:32 EDT in the session that ran stage 3, on Opus 5.5 with every subagent on Sonnet 5.5.

## Preconditions and the user's request

- D-S1. The user, at the first draft's stop of stage 3, after "no comments at this time": "Can you create the background report on this current version before doing the full production run?" The stage file provides for it: the report is written on the draft, its numbers carry the quick label, and it is rendered again after stage 3, step 6. The draft was not declared settled; the report reads the draft committed at 375b006. Stage 3 resumes at step 6 (or a revision round, if the report raises an issue) when the user says so.
- `STATUS.md` read `3, draft at stop`; set to `4, in progress`.
- D1. Workflow 0.2.4 was synced into the repository by another session at 12:37 (commit 48981f2), during step 1: the background report now runs between `3, settled` and the production run, its precondition is `3, settled`, and its stop returns the production run's estimated runtime. The commit also carried this session's uncommitted edit of `STATUS.md` (`4, in progress`). The user's request is read as settling the draft for the report: "I have no comments at this time" followed by the request for the report on the current version before the production run. The stage record gets a `3, settled` line quoting it; the report reads the draft at 375b006.
- Zotero: the plugin server answered `pong` at 12:32.
- Core citations with full text: every cited core item has its PDF with text, except the four marked `[CITE]` in the draft (Kim and Pollard 1990, Hsu 1984, Efron 1983, and the NHANES data, with Harrell 1996 supporting), which the user ruled to stay as markers (stage 3, D-S1). The report covers them as gaps.

## Time per step

| Step | Started | Ended | Agent time | Notes |
|---|---|---|---|---|
| Read the stage file and template; preconditions | 12:30 | 12:33 | 3 min | |
| 1. The map | 12:33 | 12:33 | 1 min | |
| 2. Literature: two Sonnet readers, in parallel | 12:34 | 12:45 | 11 min | reader 1 (paragraph 1, 9 sources) 8 min; reader 2 (paragraphs 2 and 3, 13 sources) 11 min; spot checks 12:43 and 12:45 |
| 3. Theory: 13 results with numerical checks | 12:34 | 12:40 | 6 min | written while the readers ran; the cube-root check extended at 12:39 |
| 4. Issues: the replay of the application (F1), `issues.md` | 12:39 | 12:46 | 7 min | |
| 5. Render, checks, revision pass, STATUS, commit | 12:46 | 12:50 | 4 min | three renders |
| Total | 12:30 | 12:50 | about 20 min | |

## The map (step 1)

### Citations of the Introduction, in order

| Paragraph | Source | Claim it supports |
|---|---|---|
| 1 | benowitz2009, tompkins2019 | a cotinine threshold separates smokers from nonsmokers; its value has been estimated from national survey data |
| 1 | hassanzad2024 | one criterion for the best threshold maximizes the sum of sensitivity and specificity; that sum minus one is the Youden index |
| 1 | bartlett2020 | multiple imputation is one of the most popular approaches to missing data |
| 1 | long2011 | depression screening scores missing for part of a cohort of pregnant women were multiply imputed, rates averaged per threshold, one score reported as "the unanimous optimum threshold" without uncertainty |
| 1 | abdulrahman2022, atlantis2016, wirth2024 | applied studies impute a marker and then report an optimal cutoff |
| 1 | abdulrahman2022, atlantis2016 | the two read in full do not say how the completed datasets were combined |
| 1 | thiele2023 | many studies do not report the precision of their cutpoints |
| 2 | fluss2005 | without missing data the empirical index has the largest upward bias of the usual estimators |
| 2 | bantis2019 | intervals exist for the index and the threshold |
| 2 | bantis2014 | confidence regions exist for sensitivity and specificity at the estimated threshold |
| 2 | [CITE] Kim and Pollard 1990; cattaneo2020 | the empirical threshold converges at the cube-root rate to a non-normal limit |
| 2 | wang2025weighted | as does a weighted Youden threshold |
| 2 | leyrat2019 | Rubin's rules assume approximately normal estimates |
| 2 | cattaneo2020 | the standard bootstrap is inconsistent for a cube-root estimator |
| 2 | fluss2009 | the ROC curve when the disease status is missing |
| 2 | wang2025interval, jia2026 | intervals for the Youden index when the disease status is missing |
| 2 | long2011, karakaya2015, cheng2020 | with the marker missing, imputation methods give the ROC curve and its area |
| 3 | bartlett2020 | the band's covariance by bootstrapping then imputing |
| 3 | montielolea2019 | the sup-t critical value |
| 3 | hsu1996; [CITE] Hsu 1984 | multiple comparisons with the best |
| 3 | [CITE] Efron 1983; Harrell, Lee, and Mark 1996 | the bootstrap estimate of optimism |
| 3 | [CITE] NHANES data | the application's data |

### Results the manuscript uses

| No. | Result | Where |
|---|---|---|
| 1 | The binormal curve and its closed forms: $c^*$, $J^*$, $\kappa$, and the equal-variance case | simulation design, known answers |
| 2 | The missingness intercept: the expected missing fraction as an integral over $Z \mid D$ | simulation design |
| 3 | The reported index is optimistic when the pooled curve is unbiased at $c^*$ | Introduction, Methods 2.2, S1.1 |
| 4 | The order $n^{-2/3}$ of the optimism (a sketch) | Methods 2.2, S1.2 |
| 5 | The pooling-order gap: never negative, and $\kappa \hat B_c / 2$ for quadratic curves | Methods 2.2, 2.6, S1.3 |
| 6 | The covariance of an empirical distribution function, $\{F(a) - F(a)F(b)\}/n$ | Methods 2.3 (the Rubin's-rules band) |
| 7 | Rubin's rules for one estimand, $T = \bar U + (1 + 1/L) B$ | Methods 2.3 (the pointwise intervals) |
| 8 | The covariance split, $\Sigma = V - W/M + W/L$ | Methods 2.3, S1.4 |
| 9 | The sup-t band's simultaneous coverage, and its critical value for independent coordinates | Methods 2.3 |
| 10 | The band-based set holds $c^*$ whenever the band covers the curve | Methods 2.4 |
| 11 | The comparison-based set holds the grid's best threshold when its comparisons hold | Methods 2.4, S1.5 |
| 12 | The optimism correction is exactly zero for a reproducing bootstrap | Methods 2.5 |
| 13 | One cutoff per stratum maximizes the population's Youden index stratum by stratum; the direction of the shift | Methods 2.7, Application, S1.6 |

## Findings during the report (step 4's material)

- F1. The hybrid comparison critical value of the imposed application analysis (5.15, against 2.75 at the estimated best point) comes from a numerical flaw, confirmed by a replay of that analysis with its seeds (`scratchpad/qcheck/qcheck.R`, 12:40 to 12:44): the first two grid points (0.0110 and 0.0141 ng/mL) both lie in the pile-up of values stored at the limit of detection, so their curves are identical and the variance of their difference is zero; after the eigenvalue clipping in `CovarianceSplit()` it is $1.2 \times 10^{-10}$ instead, `ComparisonQuantiles()` keeps the pair because it tests `s > 0`, and the ratio of two rounding errors enters the maximum. The per-point quantiles were 5.15 and 5.11 at those two points and 2.34 to 2.80 elsewhere; with pairs dropped when $s_{jk}^2 < 10^{-10} \max_k \Sigma_{kk}$, the first point's quantile is 2.61. The bootstrap construction is not affected (its differences over resamples are exactly zero, and $V$ is not reconstructed). The simulation's markers are continuous, so no grid points tie and the simulation is not affected. A small synthetic case shows the mechanism (Part C).
  - Correction, 2026-10-29, stage 3's revision round 1: the sentence on the simulation is wrong, and I did not check it against the quick run's replicates before writing it. Continuous markers do not prevent ties on the grid: predictive mean matching imputes observed values, and complete cases use only observed values, so two adjacent grid points with no observed value between them carry identical curves in every resample. In the first quick run the hybrid comparison critical value exceeded 3.5 in 46% of replicates of the cell with 100 per group, 60% missing, and predictive mean matching (largest 14.3), in 23% at 40% missing, and in none under normal imputation; the bootstrap critical values stayed between 2.61 and 3.57. `issues.md` and Part C are corrected; the fix and its reruns are in `log/03-manuscript.md`, Revision 1.
- F2. The supplement's order $n^{-2/3}$ holds in a complete-data check from 100 to 25,600 per group ($n^{2/3}$ times the optimism about 0.91 to 1.04, no trend); the quick run's slope (−0.52, MCSE 0.07) is imprecise, not contrary. Part B, Result 4.
- F3. Paragraph 1's applied-study sentence does not hold as written (reader 1, spot-checked): Abdulrahman et al. imputed the disease status, not the marker, and combined the 100 imputed datasets with Rubin's rules ("After imputation, estimates of the 100 imputed data sets were combined using Rubin's rules", Methods), reading the cutoff off the pooled rates; Atlantis et al. imputed predictors and their cutoff table is headed "Raw data" (Table 3), so the cutoff appears to come from the unimputed data; Wirth et al. (abstract) imputed covariates of a model. None imputes the marker whose cutoff it reports, and "the two whose full text was read do not say how the completed datasets were combined" is wrong for Abdulrahman et al. Substantive.
- F4. Long, Zhang, and Hsu (2011) call the plain nearest-neighbour method "standard" and propose new ones, so "the paper that proposed nonparametric multiple imputation for ROC analysis" is too strong; "unanimous" there means agreement across the methods compared, not across completed datasets; the number of imputations in the application is not stated. Editorial.
- F5. Sources the Introduction could cite, found in the cited papers' reference lists (none in Zotero; not read): Leeflang et al. (2008), on bias in sensitivity and specificity from data-driven cutoff selection (Thiele and Hirschfeld's reference 3; spot-checked), for paragraph 2's optimism; Youden (1950), the index's origin (Hassanzad and Hajian-Tilaki's reference 4); Shao and Sitter (1996), the origin of bootstrap-then-impute, and Murray (2018), the review Bartlett and Hughes cite for multiple imputation's popularity; Jarvis et al. (1987), the origin of the 14 ng/mL cotinine cutoff, and Jain (2018), revised cotinine cutoffs, for the application.
- F6. Benowitz et al. (2009) did give bootstrap intervals for their cotinine cutpoints (in web tables): complete-data cutpoint uncertainty has been reported in the application's own literature; and their criterion was total correct classification, not the Youden index. Editorial.
- Spot check of reader 1 (12:43): four of its passages read directly in the full text through `search_fulltext` (Abdulrahman et al. on Rubin's rules; Atlantis et al.'s "Raw data" headings; Benowitz et al.'s bootstrap; Leeflang et al. in Thiele and Hirschfeld's references): all as reported.

## Step 2: the sources read

All on 2026-10-29, through the Zotero connector, by two Sonnet readers (`get_content` and `search_fulltext` on each item; no web, no R): paragraph 1's nine sources by reader 1 (12:34 to 12:42), paragraphs 2 and 3's thirteen by reader 2 (12:34 to 12:45). Full text: benowitz2009, tompkins2019, hassanzad2024, bartlett2020, long2011, abdulrahman2022, atlantis2016, thiele2023, fluss2005, bantis2019, bantis2014, cattaneo2020, leyrat2019, fluss2009, karakaya2015, cheng2020, montielolea2019 (17). Abstract only: wirth2024, wang2025weighted, wang2025interval, jia2026 (4). Not readable: hsu1996 (a book without attachment). Not in the library in readable form (the draft's `[CITE]` markers): Kim and Pollard 1990, Hsu 1984, Efron 1983, Harrell, Lee, and Mark 1996, the NHANES data. Every passage quoted in Part A was read on that date. The report's text for each source is written from the readers' blocks in the report's own words; the passages are theirs, quoted verbatim and briefly.

**Spot checks of the readers** (the coordinator, through `search_fulltext`): reader 1's Abdulrahman et al. (Rubin's rules over 100 datasets), Atlantis et al. ("Raw data" headings of the cutoff table), Benowitz et al. (the bootstrap for the cutpoint), and Thiele and Hirschfeld's reference to Leeflang et al.; reader 2's Bantis et al. 2014 ("has not been addressed in the literature"), Cattaneo et al. (no occurrence of "Youden"), and Jia et al. (the partial index), with Fluss et al. 2005's sentence on the signs of the biases read by the coordinator in stage 3. All as reported.

## Step 3: the theory

Thirteen results (the map), each with a statement, what to know first, a numbered walkthrough, assumptions, a numerical check run at render time, and where the manuscript uses it. Every check agreed with its result: the binormal closed forms to $10^{-8}$; the missingness intercept within 0.2 binomial standard errors on 200,000 subjects; positive optimism in every cell without missing values; the order $n^{-2/3}$ (the scaled optimism 0.91 to 1.04 from 100 to 25,600 per group; weighted slope $-0.65$, MCSE 0.012); the pooling gap's formula to machine precision and its sign on 500 random curve sets; the covariance of an empirical distribution function and its bootstrap estimate; Rubin's rules (the mean of $T$ 1.04 times the Monte Carlo variance, within its own Monte Carlo error); the covariance split; the sup-t critical value for independent coordinates; the two sets' guarantees; the reproducing bootstrap; the strata's separability. The first version of the cube-root check, four sizes with 1,000 datasets each, gave $-0.61$ (MCSE 0.016), 3.5 standard errors from $-2/3$; five sizes, with the local slopes and the scaled values, showed no trend, so the check was rewritten to show the scaled optimism (F2).

## Step 5: checks by hand

- Every Introduction citation has its block in Part A, in the Introduction's order, and the five unreadable ones are named in the paragraphs' closing notes. Yes.
- Every result has its walkthrough and its numerical check chunk, and every check passed. Yes (13 of 13).
- Every quoted passage was read in Zotero in this stage, with the date. Yes (above).
- Every number is computed. The report's own numbers come through `prov()` from `results/` or from the package's functions; the counts in the Summary are computed from a table of the sources and from `issues.md`. Numbers that belong to the cited papers (a cutoff of 3.63 ng/mL, 100 imputations) appear in their passages or in the description of what a paper did; they are the literature's, not results.
- The writing rules: no em or en dash outside the reference list (checked on the rendered text); no bold lead-in beyond the labels the template carries ("What it did", "The passage", and so on); "we" not "I".

## Revision pass (the report)

One pass, `03-manuscript.md`, step 4, on the Summary, the paragraphs' closing notes, and Part C, with the source blocks' labels exempt as a template's labels.

- Summary, paragraph 3: "Thirteen issues were found, none blocking and five substantive" carried typed counts; now computed from `issues.md`. Its list of the five substantive issues names each in the order of the table.
- Part A, the three closing notes: read for answer-first order; each already states the claim a group of sources carries and then the verdict, so none changed.
- Part C, C1: "the inflation grows without bound" claimed more than the demonstration shows; now "how far the quantile moves depends on the ratio of two rounding errors, which nothing in the procedure controls", with the application's 5.15 as the observed case.
- Part B, Result 7: "the imputation model has only an intercept" was wrong (the noise auxiliary stays in); now says the auxiliary is pure noise, so the model is correct for values missing completely at random.
- No section changed by more than three sentences, so no second pass.

## Process feedback

1. **The stage file changed under the stage (D1).** Workflow 0.2.4 arrived at 12:37, during step 1, from another session; it reversed the order with the production run and changed the precondition to `3, settled`, which this stage then met only by reading the user's words. The sync commit also carried this session's uncommitted `STATUS.md`. A sync could wait for a stop, or say in its commit which uncommitted files it took.
2. **"Settled" without the word.** The user had no comments and asked for the report; the precondition `3, settled` needs the user to say "settled". The stage file could accept a request for the report as settling the draft for it, or say to ask.
3. **Reading in two workers.** The split of step 2 between two readers by paragraph worked (11 minutes for 22 sources, 600,000 tokens between them), and both found substantive problems the drafting missed: the applied-study sentence and the cube-root attribution. Their reports were faithful on every spot check. The stage file could recommend this split by default and ask each reader for the "further sources" list, as here, which produced most of C5 and C13.
4. **Numbers from the literature.** "Every number is computed" cannot hold for a report that describes what papers found (a cutoff, a count of imputations); the check was read as applying to the report's own results. The stage file could say so.
5. **The replay of a run.** Diagnosing C1 needed the application's intermediate covariance, which `MiYoudenInference()` does not return; the replay re-ran its steps in the same order with the same seed (3 minutes). Returning the covariance and the per-point quantiles from the procedure would make such checks a lookup.
6. **A numerical check that fails at first.** The first cube-root check was 3.5 standard errors from its target, which the stage file would have made an issue; more sizes showed noise around the target. The stage file could say that a failing check is first rerun with more replicates or sizes before it becomes an issue, and that both runs are logged.
7. **Time.** About 20 minutes from the request to the stop, against a stage written for a day; the two readers and the theory ran in parallel.
8. **A claim of scope checked against the runs' records.** F1 said the simulation was not affected, reasoning from the marker's distribution; the quick run's per-replicate file, already in `results/`, showed in one query that it was (found when the fix started, revision round 1). The stage file could say that an issue in the code is checked against every run on record (the pilot's, the quick run's, the application's) before the report says what it touches.
