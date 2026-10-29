# Decisions log: pilot-c

Each decision says what was decided, the alternatives, why, what the user should check, and the file that holds its numbers. The earlier pilots' decisions are `pilot/decisions.md` and `pilot-b/decisions.md`; those pilot-c relies on carry over (the cutoff's convention, the exact average, the normal engine, the variance split, the optimism read at each curve's chosen cutoff). The pre-registration is `pilot-c/preregistration.md`.

## D0. The literature pass

No new literature was read. The comparison-based set follows the proposal's own definition of the near-optimal set (`proposal.md`, section 3, row 2) in the manner of multiple comparisons with the best, for which no source is in the Zotero library (a `[CITE]` marker in section 13).

## D1. The status call

The status is `piloted-close-call`, by the pre-registered rule (`pilot-c/preregistration.md`, section 5), applied by `pilot-c/verdict.R` (`pilot-c/results/verdict.rds`). Questions 1 and 2 pass clearly. Question 3's clause (a) passes, and so do the comparison-based sets' coverage and length for both constructions. Each construction fails one criterion, its band's simultaneous coverage in the base cell, and in both the estimate is within three MCSE of the 0.93 limit; that makes question 3 a near fail and the status a close call.

The reading that passes: every revision did what it was meant to. The comparison-based set holds the best threshold in nearly every replicate at about half the band-based set's length; the 20-imputation correction removes most of the optimism and no longer overshoots with normal imputation at 60% missing; the grid holds $c^*$ in every replicate; and the band covers inside the limits without imputation and with the normal engine, missing the limit only in the base cell, by less than one MCSE.

The reading that fails: the band is slightly liberal in every cell, at 0.92 to 0.95 rather than 0.95, below the limit with predictive mean matching at 40% missing and further below at 60%. The two constructions share the covariance and differ only in their critical values, which are nearly equal, so the shortfall lies in the covariance of the curve with predictive mean matching, not in the critical value; more resamples moved the base cell's coverage only from the re-pilot's 0.910 to about 0.93. The comparison-based set is still several times wider than the true range of thresholds within 0.01 of $J^*$, and its coverage, near 0.995, says its critical value is conservative.

What the user should check: the numbers behind both readings in `pilot-c/results/verdict.csv` and `pilot-c/results/cell_summaries.csv`, and D5 below.

## D5. A cell that differs from the re-pilot

The 60% predictive-mean-matching cell's mean optimism is larger here than in the re-pilot's same cell (`pilot-b/results/cell_summaries.csv`), by about three combined MCSE; the other four cells agree. The two cells share the design and the code that computes the optimism and differ in their seeds. Nothing in the comparison points at a bug, but a rerun of that cell with a third seed would settle it before the production run.

## D2. The replicate count

What: 1,300 replicates per cell instead of the pre-registered 2,000. The timing run (ten replicates of every cell on seven workers, `pilot-c/results/timing.rds`) projected 2,000 replicates at more than the one-hour box; the pre-registered rule lowers the count to the largest multiple of 100 that fits. Alternatives: a longer run, which the pre-registration did not provide for. Why: the rule. Consequence: the MCSE of a coverage near 0.95 is about 0.006 rather than 0.005. Check: the projection in `pilot-c/results/timing.rds` and the runtime in `pilot-c/results/run_info.rds`.

## D3. Seven workers

What: seven PSOCK workers, the user's allowance of up to eight cores for pilot-c against the three of `rules.md`, section 5. Replicates run in blocks of 100 with seeds from the design table, so seven workers share five cells. The test subagent's single R process ran during the timing run, within the eight. Check: the block times in `pilot-c/results/run_info.rds`.

## D4. The comparison-based set's critical value

What: the largest over grid points of the per-point 95% quantile of the one-sided maximum comparison, computed from the resamples (bootstrap construction) or from normal draws with the split covariance (hybrid construction). Alternatives: one quantile of the maximum over all pairs, valid but wider; comparisons with the estimated best threshold only, narrower but without the guarantee. Why: the per-point quantile at the true best point is what the guarantee needs, and the largest over points covers whichever point is best. Check: the critical values `q_comp_boot` and `q_comp_hybrid` in `pilot-c/results/cell_summaries.rds`.

## What was not done

- The flat shape, 1,000 per group, the kernel estimator, impute-then-bootstrap, the nearest-neighbour engine, and the application: left to the full design.
- A less conservative critical value for the comparison-based set (for example comparisons with the estimated best threshold only), which the near-0.995 coverage invites.
- A correction for the band's undercoverage with predictive mean matching, for example a covariance that inflates the imputation part, which this pilot diagnoses but does not test.
- The run took slightly longer than the hour (`pilot-c/results/run_info.rds`); the timing run, with five tasks for seven workers, underestimated the per-replicate time under full load.
