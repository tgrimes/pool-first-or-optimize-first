# Stage 2 log: project spec and pilot

Workflow 0.2.1 (`workflow/02-pilot.md`, `workflow/rules.md`). Started 2026-10-28 at about 23:04 EDT, in a session started by the stage 1 coordinator session, on Opus 5.5 with every subagent on Sonnet 5.5. Inputs read in full: `STATUS.md` (`1, proposal final`), `workflow/02-pilot.md`, `workflow/rules.md`, `proposal.md`, `log/01-idea-review.md`, `manuscript/citations.csv`, `templates/project-spec.md`, `templates/pilot-report/` (README, template, helpers, parts), `tools/init.R`, and the stage 1 hand-over note in the shared notes folder.

## Time per step

| Step | Started | Ended | Agent time | Notes |
|---|---|---|---|---|
| 0. Read the inputs | 23:04 | 23:07 | 3 min | |
| 0. `tools/init.R`: question, run, commit | 23:07 | 23:08 | 1 min | the author line asked with one question |
| 0. `renv::restore()`, `uv sync` | 23:08 | 23:09 | 1 min | 99 packages linked from the cache in 3 s; uv 7 packages |
| 1. The spec | 23:10 | 23:18 | 8 min | NHANES documentation pages, the Long et al. algorithm (subagent), the download question |
| 2. Pre-registration, commit | 23:17 | 23:19 | 2 min | commit 4b2c457 at 23:19:56 |
| 3. Code, tests, timing, check | 23:20 | 23:37 | 17 min | functions in `R/`, known-answer checks, `pilot/pilot.R`, `pilot/nhanes.R`, the download; unit tests by a Sonnet subagent in parallel; timing 23:34 to 23:35; `devtools::test()` 0 failures, `devtools::check()` 0 errors, 0 warnings, 0 notes at 23:37 |
| 4. Run | 23:37 | 00:19 | 41.5 min of compute | three PSOCK workers, vecLib pinned to one thread; the report's static sections, the decisions log, and the process feedback were written meanwhile |
| 5. Verdict; tests and check rerun | 00:19 | 00:20 | 1 min | `piloted-fail`; 0 test failures, check clean |
| 6. Decisions log, spec section 3 | 00:20 | 00:21 | 1 min | most of it drafted during the run |
| 7. Report: fill, render, check, look, revise | 00:21 | 00:25 | 4 min | three renders; checker clean each time |
| 8. STATUS, log, commit | 00:25 | 00:28 | 3 min | |
| Total | 23:04 | 00:28 | about 1 h 24 min | of which 42 min the run; against a working day of agent time and an hour of compute |

## Preconditions

- `STATUS.md` read `1, proposal final`; the proposal's one open question was the author line for `tools/init.R`.
- `tools/init.R` had not run. The proposed command used the proposal's title in title case (an `R CMD check` NOTE otherwise) and the git name; `git config user.name` returned a handle, which `init.R` would have split into an empty given name, so the user was asked for the author line and confirmed it, with no coauthor and no affiliation yet. Run and committed ("Stage 2, step 0: tools/init.R run for micutoff", 130a78d). `init.R` wrote a placeholder second author, `person("FILL", "second author")`, into `DESCRIPTION` because no `--coauthor` was given.
- `renv::restore()` and `uv sync` ran clean; `uv run pytest` passed its placeholder test.
- The dataset: NHANES 2017-2018 was `verified` at stage 1; the pilot is a simulation, and the application data are described, not analysed. The documentation pages of `COT_H`, `COT_I`, and `COT_J` were read on 2026-10-28 (through the page-fetch tool, which returns a model's summary with quotations): all three name isotope-dilution high-performance liquid chromatography with atmospheric pressure chemical ionization tandem mass spectrometry and a lower limit of detection of 0.015 ng/mL, with values below it set to the limit over the square root of two and flagged by `LBDCOTLC`. The 2013-2014 page says the method and equipment changed from 2011-2012; the 2015-2016 and 2017-2018 pages say there were no changes. Stage 1's D18 check passes. Codebooks for `DEMO_J`, `SMQ_H`, and `SMQ_J` were read for the variable codes (`RIDRETH3` 1, 2, 3, 4, 6, 7; `RIDSTATR` 1, 2; `SMQ020` and `SMQ040` with `SMQ040` asked only after a yes to `SMQ020`).
- Download: the user approved downloading the nine files (about 19.2 MB, sizes read from HEAD requests) and keeping `data/raw/` out of git; `.gitignore` changed accordingly.

## What was read for the method

- Long, Zhang, and Hsu 2011 (Zotero 22HPQNWL, full text through the connector, by a Sonnet subagent; quotations spot-checked against the extracted text): section 2.3 defines the two working models with $D$, $Z$, and interactions, the standardized scores, the weighted distance with $w_1 + w_2 = 1$, and the $K$ nearest observed subjects with the same disease status, one drawn at random; section 2.4 adds the bootstrap step (refit both models on a bootstrap sample "from the original observed dataset", then impute the original data) and says all its methods are equivalent with one auxiliary; section 3 uses $K = 3$ and $L = 10$; section 2.5 averages the true and false positive rates per threshold across imputations. Ambiguities: the bootstrap sample's population and the donor pool are not stated outright (read as all subjects, and the original observed subjects with the same status).

## The timing run and the run

The timing run (`Rscript pilot/pilot.R timing`, 23:34 to 23:35) ran ten replicates of all 22 data cells on two workers, so that the test subagent's R process stayed within the three-core cap; the per-cell times and the projection for three workers are in `pilot/results/timing.rds`. The projection for 500 replicates was within the one-hour box, so the pre-registered count stood (`pilot/decisions.md`, D11). `uptime` before the run showed a load of about 3 from other work on the machine (8 cores). The run started at 23:37 (`Rscript pilot/pilot.R`, in the background), after `STATUS.md` was set to `2, pilot running`; its own log is `pilot/results/pilot.log`.

The run finished at 00:19 in 41.5 minutes (`pilot/results/run_info.rds`), not the projected 26: `parLapplyLB()` splits the cells into contiguous chunks (twice as many chunks as workers) rather than one cell per task, so the four slowest cells, the nearest-neighbour cells at 1,000 per group, ran in sequence on one worker. The run stayed within the one-hour box, so it was not stopped or restarted (`uptime` and `pilot/results/pilot.log` were read during it). `chunk.size = 1` fixes it for the production run.

After the run: `pilot/verdict.R` gave `piloted-fail` (question 1 passes; question 2 passes through its third clause, the cutoff's accuracy, which favours optimizing first; question 3 fails on clause (a), not near). The test suite and `devtools::check()` were rerun at 00:20, after the subagent's late edits to four test files: 0 failures; 0 errors, 0 warnings, 0 notes.

## Decisions

Numbered from D0 in `pilot/decisions.md`, which holds the pilot's decisions with their files; this list is the process decisions only.

- P1. The two estimators are applied to the same completed datasets (pre-registration, section 3, "reading").
- P2. The known-answer checks live in one function, `KnownAnswerChecks()`, so that the test suite asserts them and `pilot/pilot.R` saves the same table for the report.
- P3. Unit tests for the functions in `R/` were written by a Sonnet subagent, with the known-answer test and `R/known.R` kept by the coordinator, so that two writers never touched the same file. Its report named four minor points, none a bug in a result: `RunDataCell()` leaves the session on the L'Ecuyer-CMRG generator; `SummarizeAllCells()` returns permuted row names (cosmetic); two clauses of `ApplyPassRule()` would fail on a missing ratio rather than return "not met" (not reached); `ImputePmm()` with one donor is not deterministic, because `mice` redraws the regression coefficients (as intended).
- P4. The run was not restarted when it ran longer than projected (above).
- P5. The report cites Rubin (1987) and Silverman (1986) in footnotes with `[CITE]` markers: neither is in the Zotero library, and both name standard methods the report uses.

## Revision pass (spec, `03-manuscript.md` step 4.7)

- Header: the template's Authors row asked for names, which `rules.md` section 1 forbids in a deliverable; it now points at `DESCRIPTION`.
- Section 1, why it matters: one sentence carried the fix, its reason, the band, and why Rubin's rules fail; split into three, reason after "because".
- Section 2, first sentence: the setup came before the answer; rewritten answer first ("The mean of the per-dataset maxima is never below...", with the reason after "because"). A sentence joined by a semicolon split in two.
- Section 3, question 3(c): "covers in between 92% and 98%" said what covers what only implicitly; now "contains the true value in 92% to 98% of the base cell's replicates".
- No section changed by more than three sentences, so no second pass.

## Revision pass (report, `03-manuscript.md` step 4)

- Summary, status: one sentence carried the rule, the existence of the effect, the share of the bias removed, and the 0.005 line; split into three.
- Potential impact, first paragraph: the answer (no published method gives the cutoff, its index, and their uncertainty) moved from the last sentence to the first, ahead of the description of the default.
- Potential impact, last paragraph: written before the run as a forecast of what the pilot would decide; now states what it found (gap below 0.01, so the impact lies on inference: the diagnostic and the undercoverage), with cross-references.
- Findings 3 and 7: finding 3 claimed the closed form holds for the kernel curve with the pooled curve's curvature, which is true with 40% missing (ratio 0.97 to 1.00) and not with 60% (0.59 to 0.98); restricted to 40% and both ranges given. Finding 7 said "lower in each" without computing it; now a computed count.
- Rendering: the spec's `<year>` in a URL was read as an HTML tag; one MCSE in the spec-numbers table rounded to 0.0000. Both fixed.
- No section changed by more than three sentences after the first pass, so no second pass.

## Process feedback

What in the stage file, the templates, or the rules left the agent guessing, was unclear, or could be simpler, with the time it cost. Times are from the table at the top.

1. **`tools/init.R` and the author line (step 0, 1 min, plus one question).** `git config user.name` is often a handle; `init.R` splits the name on its last space, so a handle becomes `person("", "handle")`. The stage file (or `init.R`) should ask for the name as "Given Family" and refuse a one-word name. `init.R` also writes a placeholder second author, `person("FILL", "second author")`, into `DESCRIPTION` and `README.md` when `--coauthor` is absent; it should leave the coauthor out. `R CMD check` raises a NOTE on a `Title:` not in title case, so the stage file should say to pass the title in title case.
2. **The download needs the user's approval.** The spec template says the dataset is downloaded before the pilot runs, and downloading a file needs the user's explicit permission. The stage file does not say so, so the question came as a second interruption after the author line. The stage file's preconditions could list "ask the user to approve the download (file names, source, sizes) and whether raw data are committed" alongside the init question, in one message. Cost: one extra question round.
3. **An application with no application part.** Step 4.3 covers "the application part of the pilot, if the proposal has one"; this proposal's pilot had none, yet the report requires a real-data figure, a cohort table, and the application section, and the spec requires the data downloaded. A description script was needed; its place (`pilot/nhanes.R`), its output (`pilot/results/nhanes_summary.rds`), and its run file name were guesses. The stage file could name a "data description" script for this case.
4. **Variable codes from memory.** The cohort function was first written with the NHANES race and smoking codes from memory, then checked against three codebooks. The stage file's download step could say: every variable code used is read from the codebook and the page is logged.
5. **The pass rule left cases open.** The proposal's rule did not say how the three answers combine into a status, whether a threshold is judged on the point estimate or beyond its MCSE, which estimator the 60% clause means, or what a largest gap between 0.005 and 0.01 means. The pre-registration stated five readings, flagged as readings. A pre-registration template with slots for "how the answers combine" and "how a threshold near its MCSE is read" would make these explicit, and stage 1 could ask for the combination rule. There is no template for `pilot/preregistration.md`.
6. **Step 1.4, "if writing the spec changes the pass criteria, stop".** It is not clear whether filling an open case counts as a change. It was treated as not a change, and every reading is listed in the stop message for the user to check.
7. **Step 3.5, "time one cell of each method at the largest sample size".** "Method" could be the engine or the estimator. All 22 cells were timed at ten replicates (about a minute), which gives the projection directly; the stage file could say that.
8. **Known-answer checks as tests and as report content.** Step 3.2 puts them in `tests/testthat/`, and step 7.1 wants the report to display their outcomes "from saved files", but testthat saves no numbers. The bridge used here: one function, `KnownAnswerChecks()`, that the test asserts and the pilot script saves. The stage file could prescribe it.
9. **The three-core cap and parallel subagents.** The unit tests were written by a subagent that ran R while the coordinator needed the timing run; the timing used two workers and the pilot waited for the subagent's last R call. The stage file could say that delegated test-writing finishes before the timing run, or that a subagent runs no R while workers are up.
10. **Tests changed after the last test run.** The subagent edited four test files (tolerances, one added assertion) at 23:37, after the coordinator's test and check runs (23:36, 23:37) and as the pilot started; the suite was rerun after the run. The stage file's "tests and check run clean before the run" needs the test files frozen before that run.
11. **Commit points against the code.** `rules.md` section 1 lists the commit points and says "nowhere else". The pilot's code is therefore not committed before the run, only with the report at step 8, and the lockfile change sits uncommitted although section 5 says to commit it after a change to `DESCRIPTION`. Either a commit of the code before the run ("Stage 2, step 3: code") or an exception for the lockfile would remove the conflict.
12. **The marker form.** `rules.md` writes the marker `[TO CONFIRM: ...]{.tc}`; `templates/project-spec.md` and the report helper `read_md_part()` expect `[TO CONFIRM: ...]` and add `{.tc}` themselves, which doubles the class. The report removes the doubled class; the helper's pattern should accept both forms.
13. **Rendering from `pilot/`.** Quarto starts R in `pilot/`, where no `.Rprofile` activates the project library; `manuscript/` ships one for the same reason. `pilot/.Rprofile` was copied from it. The template should ship it, or the report README should say so.
14. **The Authors row of the spec template** names people, which `rules.md` section 1 forbids in a deliverable. The row should read "as in `DESCRIPTION`".
15. **Spec section 6.** The stage file says to take "the last three lines" of the journal worksheet; the template has two fields (target, fallback), and the third line (the target's limit and AI policy) went in as an unlabeled line. The template could add a third label.
16. **Spec template leftovers.** Its notes speak of single-cell or spatial data, counts and log-CPM, and the LIONESS edge, from an earlier project; harmless, since the notes are deleted, but a domain-neutral wording would read better.
17. **The page-fetch tool returns summaries.** Facts about datasets were read through a tool that summarizes a page with quotations. The rules' "nothing from memory" is met, but a summary is not the page; the log says which facts came that way.
18. **`parLapplyLB()` and its chunks.** The run took 41.5 minutes against a projection of 26, because `parLapplyLB()` chunks the task list by default; the stage file (or `rules.md`, section 5) could say `chunk.size = 1` for simulation cells of unequal cost, and the projection in the timing run should model the same scheduling. No restart was needed.
19. **A fail by a clause that presumes the answer.** Question 3(a) required pooling first to remove half the index's bias, which presumes the gap is most of that bias; the pilot shows it is not. The rule decided the status as written, and the decisions log gives the reading that keeps the project (D1). The stage file's close-call status covers an estimate near its threshold, not a clause whose premise fails; the user's decision at the stop is the place for that, and the stop message says so.
20. **The report's forecasts.** Sections written during the run (potential impact) forecast what the pilot would decide and had to be rewritten after it. The README could say to write the impact section after the verdict.
21. **Time.** The stage took about 1 h 24 min of wall time, 42 min of it the run; the agent's own work, about 40 min, was spread around the run. The working-day box is far above what it needed.

## Stop: the user's answer (2026-10-29, 00:33)

- D-S1. The user chose the re-scope: revise the proposal with Aim 2 (inference and the optimism correction under imputation) leading and the pooling-order result as a closed-form note, then re-pilot in `pilot-b/`. The revision is `proposal.md`, section 12, dated, at the end; the sections before it stand as the record. The user asked for the re-pilot to follow the revision directly, so the revised proposal and the re-pilot's pass rule were not shown to the user before the re-pilot ran; the revision carries a `[TO CONFIRM]` marker saying so, and the stop message names it.
- D-S2. `STATUS.md` returned to `2, spec`, with the stage record keeping the `piloted-fail` line of the first pilot.
- D-S3. The re-pilot's report reads the first pilot's NHANES description from `pilot/results/` read-only, rather than copying the script and its output into `pilot-b/`.
- D-S4. The test subagent's mutation checks found one change its tests cannot see: starting the corrected index from the maximum rather than from the pooled curve at the chosen cutoff, which differs only when tied maximizing intervals lie apart. The reproducing-bootstrap known-answer check covers `BootOptimism()`; the starting point in `RunReplicateB()` is checked by reading the code.

# Re-pilot (`pilot-b/`)

## Time per step

| Step | Started | Ended | Agent time | Notes |
|---|---|---|---|---|
| 0. Decision recorded; proposal revision (section 12) | 00:33 | 00:35 | 2 min | committed with the spec as a revision round, 3a801c7 |
| 1. The spec, rewritten | 00:35 | 00:36 | 1 min | sections 1 to 4, 8, 9; 5 to 7 carried over |
| 2. Pre-registration, commit | 00:36 | 00:37 | 1 min | 057ad2c at 00:37:25 |
| 3. Code, known answers, amendment, timing, tests, check | 00:37 | 00:52 | 15 min | the reproducing-bootstrap check failed on the first definition of the optimism; amendment 5626ff5 at 00:40:34, before any run; timing at 00:41 (7 minutes projected for 500 replicates); unit tests by a Sonnet subagent (00:41 to 00:51, 657 expectations, with mutation checks); the coordinator waited for it before the run; `devtools::test()` 0 failures and `devtools::check()` 0/0/0 at 00:52 |
| 4. Run | 00:52 | 01:01 | 9.1 min of compute | three PSOCK workers, one cell per task; the report's static sections written meanwhile |
| 5. Verdict | 01:01 | 01:02 | 1 min | `piloted-close-call` |
| 6. Decisions log, spec section 3 | 01:02 | 01:03 | 1 min | |
| 7. Report: fill, render, check, look, revise | 01:03 | 01:04 | 2 min | three renders, checker clean each time |
| 8. STATUS, log, commit | 01:04 | 01:06 | 2 min | |
| Total, re-pilot | 00:33 | 01:06 | about 33 min | of which 9 min the run |

The run (`pilot-b/results/run_info.rds`) finished in 9.1 minutes against a projection of 7, with one cell per task. The verdict: question 1 passes (optimism of the reported index, and pointwise intervals that cover the whole curve in well under 0.90 of replicates), question 2 passes, and question 3 fails only on clause (b) in the base cell with predictive mean matching, within its MCSE of the 0.92 limit, so the status is a close call (`pilot-b/decisions.md`, D1). Workflow 0.2.2 was committed into this repository by another session at 01:03, during step 7 (`workflow/` only: memo mode after a dropped or parked decision, and more banned workflow words); nothing in the re-pilot's procedure changed, the stop message lists the new options, and the version row of `STATUS.md` was updated.

### Revision pass (re-pilot report)

- Summary, status: "within its Monte Carlo error" said less than the number; now the distance in MCSE, computed. "Covers between 0.91 to 0.94" was ungrammatical; reworded.
- Findings: finding 5's bold claim carried typed numbers; rewritten without them. "1.000 to 1.000" for a constant now reads "every replicate of every cell", computed. Finding 10 cited a table without the gap; the gap and the RMSE ratio were added to the cell table. A finding was added from the replicate scatter: the correction does not track a study's own optimism (correlation computed); D1's failing reading now names it.
- Potential impact: written after the run, with the numbers the re-pilot found and cross-references, the first pilot's lesson 20.
- "Precision of cutpoints often goes unreported" used a justify-or-replace word; now "many authors do not report", the passage's own claim.
- No section changed by more than three sentences after the first pass, so no second pass.
22. **Who revises the proposal at a re-scope.** The stop says "the user revises the proposal (a dated revision section at its end)"; here the user asked the agent to. No step says how the agent writes that section (which sections it may change, whether stage 1's revision pass applies); a dated section 12 that governs where it differs, with the body kept as the record, was the reading used.
23. **A stop for the revised proposal.** The user asked for the re-pilot to follow the revision directly, so the revised proposal and the re-pilot's pass rule reached the user only at the re-pilot's stop. The stage file could say whether a revised proposal needs its own stop before a re-pilot; the rules say the user reviews every deliverable, and a `[TO CONFIRM]` marker in the revision carried the gap.
24. **Where a re-pilot's log goes.** The re-pilot was logged in `log/02-pilot.md` under its own heading, with the user's answer to the first stop as D-S1 to D-S4 and the stage record keeping both stop lines. The stage file could say so.
25. **An amendment before any run.** A known-answer check failed after the pre-registration was committed and before the run; the fix was a dated amendment in the pre-registration, committed before the run. `rules.md` speaks of changes after production results, not of an amendment before a pilot runs; one line allowing it, with the commit order as the safeguard, would settle it.
26. **A coverage criterion without a width criterion.** The re-pilot's clause on the near-optimal set passed because the sets are wide, about two-thirds of the grid; coverage alone cannot fail a set that includes nearly everything. The stage 1 guidance on pass rules could ask for a size criterion beside every coverage criterion.
27. **Two sessions in one repository.** Workflow 0.2.2 was committed here by another session at 01:03, while this session was in step 7; it touched only `workflow/`, so nothing collided, but `STATUS.md`'s version row went stale until updated here. A template sync could update that row itself, or wait for a stop.
28. **Time.** The re-pilot took about 33 minutes from the user's answer to the commit, 9 of them the run; the whole stage, both pilots, about 2 hours.

## Re-pilot stop: the user's answer (2026-10-29, 01:22)

- D-S5. Asked first what revisions the agent would suggest for a pilot-c; the agent named five (the comparison-based set the proposal defined, matched imputations for the optimism correction, the band's calibration with more resamples and replicates and a null-cell criterion, a grid from completed values, a sharp-only design). The user approved them: "Go ahead with these revisions for pilot-c."
- D-S6. The user allowed up to 8 cores for pilot-c's compute, against the 3 of `rules.md` section 5. Applied for pilot-c only: seven PSOCK workers and the coordinating process. Recorded here as the user's ruling; whether the rule should change is the user's to decide.
- D-S7. The revision is `proposal.md`, section 13. Its pass rule was written by the agent from the approved revisions and pre-registered without a separate stop, as at the re-scope; the revision carries a `[TO CONFIRM]` marker.

# Pilot-c (`pilot-c/`)

## Time per step

| Step | Started | Ended | Agent time | Notes |
|---|---|---|---|---|
| 0. Decision recorded; proposal section 13 | 01:22 | 01:24 | 2 min | |
| 1. The spec, section 3 and small changes to 2 and 4 | 01:24 | 01:25 | 1 min | revision round committed, d4d4b95 |
| 2. Pre-registration, commit | 01:24 | 01:25 | 1 min | 93f61eb at 01:25:29 |
| 3. Code, known answers, timing | 01:26 | 01:29 | 3 min | all seven known-answer checks passed first time; timing on seven workers, 01:28 to 01:29: 2,000 replicates projected at 88 minutes, so 1,300 (decisions D2); per-replicate time about 2.5 times the single-core time with seven workers busy |
| 3b. Tests and check | 01:28 | 01:38 | 10 min | unit tests by a Sonnet subagent during the timing run (one R process, within the eight cores the user allowed; 820 expectations); full suite 2,597 expectations, 0 failures; check 0/0/0 at 01:38 |
| 4. Run | 01:38 | 02:41 | 62.3 min of compute | seven PSOCK workers, blocks of 100 replicates; the report's static sections written before the run |
| 5. Verdict | 02:41 | 02:42 | 1 min | `piloted-close-call` |
| 6. Decisions log, spec section 3 | 02:42 | 02:44 | 2 min | |
| 7. Report: fill, render, check, look, revise | 02:44 | 02:48 | 4 min | three renders, checker clean each time |
| 8. STATUS, log, commit | 02:48 | 02:50 | 2 min | |
| Total, pilot-c | 01:22 | 02:50 | about 1 h 28 min | of which 62 min the run |

The run (`pilot-c/results/run_info.rds`) took 62.3 minutes against a projection of 57. Under full load a block of 100 replicates took up to about 600 seconds, against about 410 in the timing run, which had five tasks for seven workers; the later blocks ran faster as the load fell. The run was not stopped: the pre-registration sets the replicate count before the run and says nothing of stopping one, and the overrun was small. `uptime` during the run showed a load of about 13, of which seven processes were the workers; nothing else used real CPU.

The verdict: questions 1 and 2 pass; question 3 passes clause (a) and the comparison-based sets for both constructions, and fails each construction's band coverage in the base cell, within three MCSE of 0.93, so the status is a close call (`pilot-c/decisions.md`, D1). The 60% predictive-mean-matching cell's optimism differs from the re-pilot's by about three combined MCSE (D5).

### Revision pass (pilot-c report)

- Finding 6 printed "1.000 to 1.000" for a constant; now "every replicate of every cell", computed. Its "often" was a justify-or-replace word; replaced by what was observed.
- Finding 8 claimed the two constructions' coverage differs by less than its MCSE in every cell, which the 60% predictive-mean-matching cell contradicts; now the computed largest difference and where it is.
- Finding 9 asserted why Rubin's rules undercover with predictive mean matching; the pilot cannot separate too little between-imputation spread from bias, and the finding now says so.
- No section changed by more than three sentences after the first pass, so no second pass.
29. **The core cap and a timing projection on mixed cores.** With seven workers busy, a replicate took about 2.5 times its single-core time; the machine's eight cores are probably not all alike (the system reports eight, with other work on it). The one-hour box then lowered pilot-c's replicates from 2,000 to 1,300 by the pre-registered rule. The stage file could say to time with as many workers as the run will use, which was done here, and that the single-core time is not a guide.
30. **Cells fewer than workers.** Pilot-c has five cells and seven workers, so cells were split into seeded blocks of 100 replicates (seed $20261030 + 1000k + b$); the per-cell seed of the earlier pilots would have left two workers idle. The stage file's "each cell its own seed" could allow seeded blocks within a cell.
31. **A timing run with fewer tasks than workers.** Pilot-c's timing ran one task per cell, five tasks on seven workers, so it measured the per-replicate time under less load than the run had; the run took 62 minutes against 57 projected. The timing run should load every worker, for example by timing blocks.
32. **Time.** Pilot-c took about 1 h 28 min from the user's answer to the commit, 62 minutes of it the run; the stage, three pilots, about 3 h 45 min of wall time.
