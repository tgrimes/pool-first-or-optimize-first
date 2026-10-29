# Drafting log (stage 3)

Paper test: yes on all seven questions for a constructive method paper (the Youden curve, its maximizer, and its maximum as functionals; a bootstrap-then-impute band, a comparison-based near-optimal set, and a matched optimism correction, with pilot-c's simulation behind them), with two plain noes: no closed form for the optimism of the step curve beyond its order, and no formula for the band's undercoverage under predictive mean matching; the application's "what to show" still names the first proposal's pooling-order comparison and is re-posed at the design stop, and the discrete-covariate aim has no code yet.

Workflow 0.2.3 (`workflow/03-manuscript.md`, `workflow/rules.md`). Started 2026-10-29 at 09:01 EDT, in a session started by the stage 2 coordinator session, on Opus 5.5 with every subagent on Sonnet 5.5; stops on. Inputs read in full: `STATUS.md` (`2, piloted-pass`), `workflow/03-manuscript.md`, `workflow/rules.md`, `proposal.md` with sections 12 and 13, `project-spec.md`, `protocol.md` (the template), `log/02-pilot.md`, `pilot-c/` (pre-registration, decisions, `pilot.R`, `verdict.R`, the saved summaries, timing, and run file), the functions in `R/` that pilot-c calls, `manuscript/` (the skeleton, the supplement, the helpers, the parts, the seed bib, `citations.csv`, the checker), the target journal's profile, and the three hand-over notes in the shared notes folder. `pilot/` and `pilot-b/` were read through their decisions logs, their verdicts, and `proposal.md` sections 12 and 13, which summarize them.

## Time per step

| Step | Started | Ended | Agent time | Notes |
|---|---|---|---|---|
| Read the inputs | 09:01 | 09:04 | 3 min | |
| 0. Paper test | 09:04 | 09:05 | 1 min | `STATUS.md` set to `3, drafting` |
| 1. Promote the pilot: script, functions, tests, fixtures | 09:05 | 09:07 | 2 min | `R/simulation.R`, `R/figures.R`, `analysis/01_simulation.R`, three test files |
| 1. Acceptance test, sample mode | 09:07 | 09:09 | 1.5 min | one core; 69 expectations, 0 failures |
| 1. Test suite and check | 09:09 | 09:12 | 3 min | 2,633 expectations, 0 failures; check 0/0/0 after one fix (D2) |
| 1. Acceptance test, full mode, first attempt | 09:12 | 09:14 | 2 min | failed at once: an argument-name clash in `RunBlocksParallel()` (D3); fixed, with a one-worker test |
| 1. Acceptance test, full mode, rerun | 09:15 | | | three workers, in the background during step 2 |
| 2. References: inventory, availability, the three lists | 09:13 | 09:20 | 7 min | local API and the connector; four Crossref lookups (D4) |

## Preconditions

- `STATUS.md` read `2, piloted-pass`; D-S8 of `log/02-pilot.md` carries three design questions into the design proposal: the band's calibration under predictive mean matching, the comparison-based set's conservative critical value, and the 60% predictive-mean-matching cell's recheck.
- The spec's `[TO CONFIRM]` markers (the production replicate count, the milestone dates) are carried into the design proposal and the draft.
- Target journal Statistical Methods in Medical Research, fallback Biometrical Journal (spec section 6; slug `statistical-methods-in-medical-research`: unstructured abstract of 200 words, about 8,000 words, `csl/sage-vancouver.csl`, generative AI use disclosed in the Methods or Acknowledgements).
- Zotero: `curl http://127.0.0.1:23120/ping` answered `pong` and the local API answered 200 at 09:02.
- R, Quarto 1.9.38, and uv are installed; the project library and `.venv/` were restored in stage 2.
- Core cap: three (D-S9 of the stage 2 log).

## Paper test

| Question (constructive reading) | Answer | Where |
|---|---|---|
| 1. The estimand and the gap the existing methods leave | The estimand is the Youden curve of a marker missing at random, its maximizer, and its maximum, and the true accuracy of the chosen cutoff. Existing methods give complete-data intervals for the cutoff and the index (Fluss, Faraggi, and Reiser 2005; Bantis, Nakas, and Reiser 2019), a pooled curve with no uncertainty from imputed data (Long, Zhang, and Hsu 2011), and pointwise Rubin's-rules intervals that, read as a band, cover the whole curve in a minority of replicates. The gap: no simultaneous band for the curve, no near-optimal set of thresholds, and no correction of the reported index from multiply imputed data. | `proposal.md`, section 12 (the re-scoped question and row 1); `project-spec.md`, section 1 |
| 2. The proposed procedure | Pool the empirical Youden curves of $L = 20$ completed datasets; estimate the curve's covariance on a grid by bootstrap-then-impute with two imputations per resample, split into its sampling and imputation parts and rescaled to $L$; a sup-t band with a bootstrap or a normal-law (hybrid) critical value; the comparison-based near-optimal set, which keeps a threshold unless another beats it by more than a critical value times the standard error of their difference (in the manner of multiple comparisons with the best); and an optimism correction of the reported index from 100 further resamples imputed 20 times each, as the analysis is. | `proposal.md`, sections 12 and 13; `pilot-c/preregistration.md`, section 2; `R/inference_c.R`, `R/simulate_c.R` |
| 3. The estimand as a functional | $J(c) = F_0(c) - F_1(c)$ with $F_d$ the marker's distribution function in group $d$; $c^* = \arg\max_c J(c)$; $J^* = \sup_c J(c)$; the true accuracy of a chosen threshold $J(\hat c)$ and the regret $J^* - J(\hat c)$; the target of a set on a grid, $\arg\max_k J(c_k)$. | `proposal.md`, section 3, row 3; `project-spec.md`, section 4 (estimands) |
| 4. Properties under the stated conditions | At a fixed threshold the pooled curve is an average of differences of proportions, regular, so a band built from its covariance covers at the nominal rate under proper, unbiased imputation; the comparison-based set contains the grid's best threshold whenever the comparisons involving it hold (a two-line argument, `pilot-c/preregistration.md`, section 2). The reported index is the maximum of a noisy curve, so it exceeds the chosen cutoff's true accuracy in expectation; for the step curve the excess is of order $n^{-2/3}$ (a sketch from the cube-root regime, Kim and Pollard 1990), with no closed form. The bootstrap is inconsistent for cube-root estimators (Cattaneo, Jansson, and Nagasawa 2020), so the correction's bias is shown by simulation, not derived. No formula exists for the band's undercoverage under predictive mean matching, whose imputations are biased where donors are sparse. The pooling-order gap $\kappa B_c / 2$ is a lemma. | `proposal.md`, section 4 and section 12, Aim 1; `project-spec.md`, section 2; `pilot-c/decisions.md`, D1 |
| 5. The simulation that confirms it | Pilot-c: the sharp binormal shape at 250 per group, no missing values (the null cell, where the bands are complete-data bands and the pooling-order gap is exactly zero), 40% and 60% missing at random with predictive mean matching and with normal imputation, 1,300 replicates per cell; seven known-answer checks, all passed. The optimism exists (0.026, MCSE 0.001, in the base cell), the comparison-based sets hold the best threshold in more than 0.99 of replicates at about 0.6 of the band-based sets' length, and the bands cover at 0.94 without imputation and with normal imputation, 0.92 to 0.93 with predictive mean matching at 40% missing. | `pilot-c/results/cell_summaries.csv`, `pilot-c/results/verdict.csv`, `pilot-c/pilot-report.html` |
| 6. Comparison with the existing methods | Against the default (pointwise Rubin's intervals read as a band: 0.28 simultaneous coverage in the base cell), the Rubin's-rules sup-t band (0.71 with predictive mean matching, 0.97 with normal imputation), the band-based set, the uncorrected index, the two-imputation correction, and, for the note, optimize-first against pool-first (gap 0.003, cutoff RMSE ratio 0.80). Not yet run: the complete-case intervals of Bantis, Nakas, and Reiser (2019), impute-then-bootstrap, the nearest-neighbour engine of Long, Zhang, and Hsu (2011). | `pilot-c/results/cell_summaries.csv`; `project-spec.md`, section 4 (methods compared) |
| 7. The application | NHANES 2013 to 2018 pooled, serum cotinine against current smoking among adults (16,233 with observed cotinine and a smoking answer; 9.6% of cotinine missing), missingness imposed at random so that the full-data curve is the benchmark. The spec's "what to show" still names the first proposal's comparison (the two orders' cutoffs in one near-optimal set, the optimize-first index higher by $\kappa \hat B_c / 2$); after the re-scope it should name the band covering the full-data curve, the set containing the full-data cutoff, and the corrected index against the full-data index. Re-posed at the design stop. | `project-spec.md`, section 5; `pilot/results/nhanes_summary.rds`; `R/nhanes.R` |

## Step 1: the pilot promoted

**What was carried, and from where.** Pilot-c's functions were already in `R/` with tests, so nothing was ported. `pilot-c/pilot.R` became `analysis/01_simulation.R`: a parameter block (shapes, group size, missing fractions, engines, $L$, the quick and production replicate counts, block size, workers, base seed), three modes (`timing`, `quick`, `production`), seeded blocks of 100 replicates whose seeds come from the design table ($20261030 + 1000k + b$ for block $b$ of cell $k$), PSOCK workers with the BLAS pinned, the per-replicate file `results/simulation_replicates.rds` (git-ignored by the existing pattern), the design table, the per-cell summaries, `sessionInfo()`, and `results/run_info.rds`. Until the design stop the parameter block carries pilot-c's design. What the pilot script defined inline (the logged block runner, the cluster setup) moved into `R/simulation.R` as `RunBlock()`, `RunBlocksParallel()`, `CollectBlocks()`, and `BlasPinned()`, with `SimulationDesign()` building the design table from the parameter block and `CellLabel()` naming cells. The pilot report's plot code became `R/figures.R`: `PlotBandCoverage()`, `PlotSets()`, `PlotOptimism()`, `PlotNhanesCurve()`.

**The download (step 1.3).** `analysis/00_download.R` ran in stage 2 with the user's approval; the nine NHANES files are in `data/raw/`, and the script skips files that exist.

**Assumptions found in the pilots' code comments and decisions logs (step 1.4).**

- A subject is called positive when $X > c$, so $J(c) = F_0(c) - F_1(c)$ (`R/curves.R`).
- The empirical cutoff is the midpoint of the maximizing interval of the step curve, and the mean of the midpoints when intervals tie (first pilot, D4); the optimism of a resample and the corrected index are read at each curve's chosen cutoff, not at the maximum, because the tie rule's cutoff need not attain the maximum (re-pilot, D3, the amendment).
- Every average over imputations is computed as $v_1 + L^{-1}\sum_l (v_l - v_1)$, exact for identical inputs (first pilot, D7).
- Predictive mean matching is `mice::mice.impute.pmm()` called once per imputation (5 donors, type 1 matching, predictors $D$, $Z$, $D \times Z$), which is the whole algorithm when only the marker is missing (first pilot, D3); normal imputation is `mice::mice.impute.norm()` with the same predictors (re-pilot, D4).
- Resamples are drawn within each disease group, keeping the group sizes (`ResampleWithinGroups()`).
- The covariance of the 20-imputation curve is $V - W/M + W/L$ with negative eigenvalues set to zero (re-pilot, D6; pilot-c pre-registration, section 2); the bootstrap critical value standardizes by the resample means' own standard deviation; pairs with a zero standard error of their difference are left out of the comparison critical value.
- The comparison-based set's critical value is the largest over grid points of the per-point one-sided 95% quantile (pilot-c, D4).
- The grid spans the 10% to 90% quantiles of all completed values together (pilot-c pre-registration, section 2).
- The missingness intercept is solved for the target fraction with equal group sizes and $Z = X + e$, $e \sim N(0, 1)$ (`MissingIntercept()`).
- The nearest-neighbour engine with one auxiliary is not proper: its bootstrap step leaves the donors unchanged (first pilot, D5). It is not in pilot-c's design.

**Test coverage added for code paths the pilot did not run.** `SimulationDesign()` with two shapes, two sizes, and two missing fractions (cell order, intercepts, the base cell); `CellLabel()` with factors that vary and factors that do not; `RunBlock()` with a log file; `CollectBlocks()` ordering; the four figure functions drawing to a device and restoring the graphics parameters. The production design's own code paths (other shapes, sizes, engines, or estimators) get their tests after the design stop, before the quick run.

**Acceptance test (step 1.6).** `tests/testthat/test-acceptance.R`, gated by `MICUTOFF_ACCEPTANCE`, with pilot-c's saved per-cell summaries and its per-replicate rows copied into `tests/testthat/fixtures/` (the per-replicate file, about 1 MB, is needed to compare replicates; the summaries are byte-identical copies, md5 checked). In `sample` mode (run 09:07 to 09:09, one core, the BLAS on one thread): the design table built from the parameter block equals `PilotDesignC()`; all five per-cell summaries recomputed from the saved replicates equal the saved summaries to $10^{-12}$; and the first replicate of each of the 65 seeded blocks, rerun through `RunBlock()` and `RunReplicateC()`, equals the saved row to $10^{-12}$. 69 expectations, 0 failures. The `full` mode reruns all 6,500 replicates on three workers and compares every per-cell summary; it was started after the step 1 commit (D1).

**Clean check (step 1.8).** `devtools::document()`; `devtools::test()` 2,633 expectations, 0 failures, 3 skips (the gated acceptance tests); `devtools::check()` 0 errors, 0 warnings, 0 notes at 09:11, after D2. `renv::status()` reports the lockfile consistent (the new imports are base packages).

## Step 2: references

### Inventory

Every source the draft is expected to cite: the 38 rows of `manuscript/citations.csv` as stage 1 left them, less one no longer needed; the eleven items the user added on 2026-10-29 between 08:48 and 08:59 for stage 3 (Zotero's `dateAdded`), which cover the `[CITE]` markers of `proposal.md` sections 12 and 13 (the bootstrap optimism correction, multiple comparisons with the best), the sources the pilot reports marked `[CITE]` (Rubin 1987, Silverman 1986), the software the method calls, a source on predictive mean matching, one on sup-t bands, and the two seed entries of `references.bib`; and the application's data, which no item yet covers. Sections: I Introduction, M Methods, S simulation design, A Application, D Discussion, Sup supplementary note.

| Key | Grade | Section | Why | Origin |
|---|---|---|---|---|
| long2011 | core | I, M, D | the pooled curve read without uncertainty; the published example of paragraph 1 (EPDS, "unanimous optimum threshold") | proposal |
| long2012 | definitional | M | the doubly robust nearest-neighbour imputation | proposal |
| mitra2016 | core | I, D | the order-of-operations precedent for propensity scores | proposal |
| leyrat2019 | core | I, M | Rubin's rules assume approximately normal estimates; the propensity-score precedent | proposal |
| granger2019 | core | D | Across against Within | proposal |
| wood2008 | core | D | a discrete decision made across imputations | proposal |
| mertens2026 | core | D | averaging predictions against pooling a model; what shrinks with $L$ | proposal |
| heinze2013 | supporting | D | pooling a whole distribution function across imputations | proposal |
| kim1990 | core | I, M, Sup | the cube-root rate and the non-normal limit of an argmax of a step criterion | proposal |
| cattaneo2020 | core | M, D | the standard bootstrap is inconsistent for cube-root estimators | proposal |
| seijo2011 | supporting | Sup | the argmax theorem for several maximizers | proposal |
| vandervaart1998 | core | Sup | consistency of the argmax under uniform convergence | proposal |
| schomaker2018 | supporting | M | which combinations of the bootstrap and imputation are valid | proposal |
| bartlett2020 | core | M | bootstrap-then-impute is valid under uncongeniality, impute-then-bootstrap is not | proposal |
| vonhippel2021 | supporting | M | bootstrap-then-impute with few imputations per resample | proposal |
| fluss2005 | core | I, M | the empirical Youden estimator and its upward bias | proposal |
| fluss2009 | supporting | I | the ROC curve when the disease status is missing | proposal |
| yin2016 | supporting | D | the kernel cutoff is asymptotically normal | proposal |
| bantis2019 | core | I, M, S | complete-data intervals for the index and the cutoff; the complete-case comparator | proposal |
| bantis2014 | supporting | I | confidence regions for sensitivity and specificity at the estimated cutoff | proposal |
| thiele2023 | supporting | I | many authors do not report the precision of their cutpoints | proposal |
| zhang2020 | supporting | D | the bagged cutoff, optimize then average over resamples | proposal |
| inacio2017 | supporting | D | the covariate-specific Youden index and cutoff | proposal |
| rodriguezalvarez2021 | definitional | D | the `ROCnReg` package | proposal |
| xu2014 | supporting | D | a model-free covariate-adjusted cutoff | proposal |
| ghosal2025 | supporting | D | covariates in cutoff estimation | proposal |
| wang2025weighted | supporting | M, Sup | the cube-root limit for a weighted Youden cutoff (abstract) | proposal |
| wang2025interval | supporting | I | Youden intervals under verification bias (abstract) | proposal |
| jia2026 | supporting | I | partial Youden intervals under verification bias (abstract) | proposal |
| cheng2020 | supporting | I | ROC inference with a missing marker stops at the curve | proposal |
| karakaya2015 | supporting | I | imputation for the AUC | proposal |
| abdulrahman2022 | supporting | I | an applied study that imputes and reports a cutoff, order unstated | proposal |
| atlantis2016 | supporting | I | the same, with five imputed datasets | proposal |
| wirth2024 | supporting | I | the same, Youden cutoffs after imputation (abstract) | proposal |
| benowitz2009 | core | A | cotinine cutoffs by race/ethnicity, NHANES 1999 to 2004 | proposal |
| tompkins2019 | core | A | the 3.63 ng/mL adult cutoff, NHANES 2009 to 2014 | proposal |
| hassanzad2024 | definitional | I | the criteria for an optimal cutpoint | proposal |
| rubin1987 | definitional | M | Rubin's rules | pilot reports (`[CITE]`), added 2026-10-29 |
| efron1983 | core | M | the bootstrap estimate of the optimism of an apparent error | proposal section 12 `[CITE]`, added 2026-10-29 |
| harrell1996 | supporting | M | the bootstrap optimism correction in prognostic modelling | added 2026-10-29 |
| hsu1984 | core | M | multiple comparisons with the best, the comparison-based set's construction | proposal section 13 `[CITE]`, added 2026-10-29 |
| hsu1996 | supporting | M | the same, in the textbook | added 2026-10-29 |
| vanbuuren2011 | definitional | M | the `mice` package | stage 2 (both engines), added 2026-10-29 |
| morris2014 | core | M, D | predictive mean matching where donors are sparse | `pilot-c/decisions.md` D1, added 2026-10-29 |
| montielolea2019 | core | M | sup-t simultaneous bands | pilot-c bands, added 2026-10-29 |
| silverman1986 | definitional | M | the kernel bandwidth rule, if the kernel estimator returns at the design stop | pilot reports (`[CITE]`), added 2026-10-29 |
| morris2019 | supporting | S | the ADEMP structure (`parts/ademp-sentence.md`) | seed bib |
| marwick2018 | definitional | M | the research compendium (`parts/reproducibility.md`) | seed bib |
| nhanes | definitional | M, A | the NHANES 2013 to 2018 cotinine, smoking, and demographics files | spec section 5 |

Left out: li2015 (the ADNI precedent; ADNI was set aside at stage 1).

### Availability

Checked at 09:16 to 09:20 through Zotero's local API (each record's fields, its children, and the length of each attachment's indexed full text) and the connector's `get_content` for the two items whose full text the API did not return. Available means: the record is complete enough to cite, and a PDF with readable text is attached, or the citation is supporting and the record's abstract states the claim, or the item is a book or pre-1980. A definitional citation is read as needing only a complete record (D5).

The three lists, as returned at the stop:

**(1) Available: 43 of 49.** long2011, long2012, mitra2016, leyrat2019, granger2019, wood2008, mertens2026, heinze2013, cattaneo2020, vandervaart1998 (book), schomaker2018, bartlett2020, vonhippel2021, fluss2005, fluss2009, yin2016, bantis2019, bantis2014, thiele2023, zhang2020, inacio2017, rodriguezalvarez2021, xu2014, ghosal2025, wang2025weighted (abstract), wang2025interval (abstract), jia2026 (abstract), cheng2020, karakaya2015, abdulrahman2022, atlantis2016, wirth2024 (abstract), benowitz2009, tompkins2019, hassanzad2024, rubin1987 (book), hsu1996 (book), vanbuuren2011 (definitional, no PDF), morris2014, montielolea2019, silverman1986 (book), morris2019, marwick2018.

**(2) Missing: 6.**

- Add the item:
  - NHANES 2013-2014, 2015-2016, and 2017-2018 data: serum cotinine (`COT_H`, `COT_I`, `COT_J`), smoking questionnaire (`SMQ_H`, `SMQ_I`, `SMQ_J`), demographics (`DEMO_H`, `DEMO_I`, `DEMO_J`), National Center for Health Statistics, at `https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2013/DataFiles/`, `.../2015/DataFiles/`, `.../2017/DataFiles/` (URLs as used by `analysis/00_download.R`). Needed for the Data section and the Application. One Dataset item per cycle, or one for the survey, as the user prefers; the cotinine laboratory documentation pages (method, limit of detection 0.015 ng/mL) can be attached to them.
- Attach the PDF:
  - Hsu JC. Constrained simultaneous confidence intervals for multiple comparisons with the best. Ann Statist. 1984;12(3):1136-1144. DOI 10.1214/aos/1176346732 (seen on Crossref, D4). Zotero YN7P6WNQ has no attachment and no abstract. Needed as the core source of the comparison-based set (Methods). If it is to be cited only for the idea, with the textbook (hsu1996, available) carrying the method, an abstract entered in the record would do instead.
- Attach a PDF with a text layer (the attached PDF's text cannot be read):
  - Kim J, Pollard D. Cube root asymptotics. Ann Statist. 1990;18(1):191-219. DOI 10.1214/aos/1176347498. Zotero K6CHKTHU: the PDF is a scan whose text layer holds only a 150-character notice. Core: the cube-root rate of the empirical cutoff (Introduction, Methods, supplement). Running OCR on the PDF in Zotero, or attaching a version with text, would do.
  - Efron B. Estimating the error rate of a prediction rule: improvement on cross-validation. J Am Stat Assoc. 1983;78(382):316-331. DOI 10.1080/01621459.1983.10477973. Zotero MQZ6DURG: the connector reports "PDF text extraction returned empty result" and the record has no abstract. Core: the bootstrap optimism correction (Methods). If the PDF does have text, Zotero's "Reindex Item" may be all it needs.
  - Harrell FE, Lee KL, Mark DB. Multivariable prognostic models: issues in developing models, evaluating assumptions and adequacy, and measuring and reducing errors. Stat Med. 1996;15(4):361-387. DOI 10.1002/(SICI)1097-0258(19960229)15:4<361::AID-SIM168>3.0.CO;2-4. Zotero GG8ZJ475: the same empty extraction, no abstract. Supporting: the correction's use in prognostic modelling (Methods); entering the abstract would also do.
- Complete the metadata:
  - Seijo E, Sen B. A continuous mapping theorem for the smallest argmax functional. Zotero 386ZU8ZS has no journal, volume, pages, or DOI. Enter: Electronic Journal of Statistics; volume 5; pages 421-439; DOI 10.1214/11-EJS613 (the DOI and volume seen at stage 1, the pages on Crossref, D4). Supplement.

**(3) Record faults in available items, with the value to enter.**

| Item | Zotero | Field | Now | Enter |
|---|---|---|---|---|
| kim1990 | K6CHKTHU | volume, issue | empty | 18, 1 (Crossref, D4) |
| hsu1984 | YN7P6WNQ | volume, issue, DOI | empty | 12, 3, 10.1214/aos/1176346732 (Crossref, D4) |
| li2015 | L2ADE5CM | DOI | empty | 10.1111/biom.12312 (seen at stage 1; Crossref) |
| long2012 | 68BTQRIH | issue, pages | empty; "149" | issue 1 (Crossref); the full page range, which neither the attached author manuscript nor Crossref shows |
| vanbuuren2011 | TT3PCD89 | author; issue | "Buuren, Stef van"; empty | last name "van Buuren", first name "Stef"; issue 3 (the record's own DOI, jss.v045.i03) |
| inacio2017 | DXULDB7M | authors | "Inácio De Carvalho", "De Carvalho" | "Inácio de Carvalho", "de Carvalho" |
| vonhippel2021 | GAD48MU6 | author | "Von Hippel" | "von Hippel" |
| vandervaart1998 | MFX4FI2X | author; title; publisher; volume | "Van der Vaart"; "Asymptotic statistics"; "Cambridge university press"; "3" | "van der Vaart"; "Asymptotic Statistics"; "Cambridge University Press"; move 3 to the series number and enter the series title printed on the book. The date reads 2000 (the printing in the record); keep it or enter the first edition's year, as the user prefers |
| thiele2023 | SPUB9EGM | journal | "plos one" | "PLOS ONE" |
| silverman1986 | APEC2L4I | date, publisher, place, series | 2018, Routledge | 1986, Chapman and Hall, London, Monographs on Statistics and Applied Probability (the attached PDF: "Published in Monographs on Statistics and Applied Probability, London: Chapman and Hall, 1986.") |

Faults stage 1 recorded that are now fixed in the library: the DOIs of bantis2014, thiele2023, abdulrahman2022, benowitz2009, and vonhippel2021; benowitz2009's journal; vonhippel2021's title.

## Decisions

- D1. The acceptance test runs in two gated modes. The stage file asks for the pilot's grid and seeds rerun with every per-cell summary compared; for pilot-c that is 6,500 replicates of about 1.4 seconds each on one core (from the sample run), about an hour on three workers. The `sample` mode, which reruns one replicate from every seed and recomputes every summary from the saved replicates, takes about 90 seconds and is the mode to run after any change to the code; the `full` mode is the stage file's test and was run once, in the background, during step 2.
- D2. `grDevices` moved from Imports to Suggests: the figure functions use only `graphics`, and the check flagged an unused import. The first check also raised "unable to verify current time", a NOTE from the check's clock lookup with no network time; checks run with `_R_CHECK_SYSTEM_CLOCK_=0`.
- D3. The full acceptance test's first attempt failed in every block with "unused argument": `RunBlocksParallel()` passed its extra arguments to `parLapplyLB()` under the name `fun`, which `parLapplyLB()` forwards to `clusterApplyLB()` as that function's own argument. Renamed (`log_path`, `one_rep`), with a comment, and a test that runs four blocks on one PSOCK worker and compares them with the same blocks run serially. The sample mode could not catch it, because it runs blocks in the test process; the analysis script would have failed at the quick run.
- D4. Four identifiers were looked up on Crossref (`api.crossref.org/works/<DOI>`, and one title query for Hsu 1984), on 2026-10-29 at 09:18, to give the value to enter for record faults of items already in the library: long2012 (issue), seijo2011 (pages), li2015 (confirming the DOI seen at stage 1), kim1990 (volume and issue), hsu1984 (DOI, volume, issue). No new source was sought; the stage file allows no literature search here, and these are lookups of identifiers, not searches.
- D5. A definitional citation (one that only names a method, a package, or a dataset) is read as available with a complete record and no PDF: `rules.md`, section 2, sets a requirement for core and supporting citations only. This makes `vanbuuren2011` available without its PDF.
- D6. `li2015` is left out of the inventory: its role was the ADNI precedent, and ADNI was set aside at stage 1.

## Process feedback

What in the stage file, the skeleton, the helpers, the checker, or the rules left the agent guessing, was unclear, or could be simpler, with the time it cost. Written as the stage goes; times are from the table at the top.

1. **The acceptance test costs a second pilot (step 1.6, D1).** "Runs the pilot's grid and seeds ... and compares every per-cell summary" means rerunning all 6,500 of pilot-c's replicates, about an hour on three cores. A sample mode (one replicate per seed, every summary recomputed from the saved replicates) took 90 seconds and carries most of the assurance. The stage file could name the two modes, and say that the per-replicate file goes into the fixtures beside the summaries, since a replicate cannot be compared without it (the stage file says only "the saved summaries").
2. **The cheap mode missed the bug the expensive one caught (D3).** The sample mode ran blocks in the test process; the bug was in the parallel runner the script uses. The stage file could ask that the acceptance test, in any mode, go through the same runner as the analysis script (a few blocks on the workers), so that the script's own path is tested before the quick run. Cost: 2 minutes, and a restart of the full run.
3. **The references stop has no state.** `STATUS.md` lists `3, design stop` and `3, drafting` but no state for step 2's stop; the Stage row stayed `3, drafting` and the Open stop row names the stop.
4. **Definitional citations and availability (step 2.2, D5).** The availability rule names core and supporting citations, a pre-1980 record, and a book; a definitional citation (a package, a dataset) is not covered. Read as needing a complete record only.
5. **Values to enter for record faults (step 2.3, D4).** The stop asks for "the value to enter" for each fault, but a missing DOI or volume is often not anywhere the agent may look: the record lacks it and the stage allows no search. Four Crossref lookups of identifiers filled the gap; the stage file could allow identifier lookups for faults explicitly, as stage 1 does for identifiers of sources already cited.
6. **Items added between stages.** The eleven items the user added for stage 3 were found by sorting the library by date added; neither the stage 2 log nor `citations.csv` lists them. A hand-over line in the previous stage's log (key, Zotero item, why) would make the inventory a lookup rather than a search.
7. **The spec's application after a re-scope.** `project-spec.md`, section 5, "What to show", still names the first proposal's pooling-order comparison, although section 12 of the proposal re-scoped the paper; stage 2's re-scope rewrote spec sections 1 to 4 and 8 and 9 but not 5. Re-posed at the design stop.
8. **`R CMD check` without network time.** The check raised "unable to verify current time" (a 60-second timeout and a NOTE); `_R_CHECK_SYSTEM_CLOCK_=0` removes it. `rules.md`, section 5, or the stage file could set it for every check.
