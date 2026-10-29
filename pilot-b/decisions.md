# Decisions log: the re-pilot

Each decision says what was decided, the alternatives, why, what the user should check, and the file that holds its numbers. The first pilot's decisions are `pilot/decisions.md`; those it relies on (D4, the cutoff's convention; D7, the exact average; D9, Rubin's rules for one threshold) carry over unchanged. The pre-registration is `pilot-b/preregistration.md`, with an amendment committed before the run.

## D0. The literature pass

No new literature was read. The re-scope rests on sources already in `manuscript/citations.csv`: Bartlett and Hughes (2020) and von Hippel and Bartlett (2021) for bootstrap-then-impute with few imputations per resample, Cattaneo, Jansson, and Nagasawa (2020) for the inconsistency of the standard bootstrap for cube-root estimators, Fluss, Faraggi, and Reiser (2005) for the empirical maximum's bias, and Zhang et al. (2020) for the bagged cutoff. Two sources the procedure uses are not in the Zotero library: one for the bootstrap optimism correction, and Rubin (1987) for Rubin's rules; both are `[CITE]` markers.

## D1. The status call

The status is `piloted-close-call`, by the pre-registered rule (`pilot-b/preregistration.md`, section 5), applied by `pilot-b/verdict.R` (`pilot-b/results/verdict.rds`). Questions 1 and 2 pass clearly. Question 3 passes clauses (a) and (c) and fails clause (b) in the base cell with predictive mean matching, where the bootstrap-then-impute band's coverage is within three MCSE of its 0.92 limit; a failed question 3 with every failed clause near its threshold is a close call.

The reading that passes: the correction removes most of the optimism in the base cell; the bootstrap band covers between 0.91 and 0.94 in every cell, including the 60% predictive-mean-matching cells where the Rubin's-rules band falls far below; the base cell's shortfall from 0.92 is within its Monte Carlo error; with the correctly specified normal imputation the band passes; and every near-optimal set contains $c^*$ whenever the grid does. Aim 1 of the re-scoped proposal holds, and the full design tunes the band.

The reading that fails: the band undercovers in the base cell, and it sits below 0.95 even in the null cells, where nothing is imputed, so the bootstrap sup-t band is slightly liberal at 250 per group for reasons of the bootstrap, not the imputation. The correction fixes the average optimism but does not track a study's own optimism: across the base cell's replicates the two are negatively correlated (`pilot-b/results/base_cell_points.rds`). It also overshoots below zero at 60% missing, most of all in the flat cell with predictive mean matching, where the imputations' own downward bias offsets the optimism and the correction subtracts it again. The near-optimal sets pass clause (c) because they are wide, about two-thirds of the grid, so the clause measures coverage and not usefulness; and for the flat shape the grid built from observed values misses $c^*$ in a third of replicates at 40% missing and nearly all at 60%.

What the user should check: the numbers behind both readings in `pilot-b/results/verdict.csv` and `pilot-b/results/cell_summaries.csv`; whether the set's width is acceptable; and the decision at the stop (pass, with the band and the grid tuned in the full design; or another revision).

## D2. The re-scope and its pass rule were not reviewed before the run

What: the proposal's section 12 and the re-pilot's pass rule were written by the agent and pre-registered without a stop, because the user asked for the re-pilot to follow the revision. Alternatives: a stop on the revised proposal before the re-pilot. Why: the user's instruction. Check: the three questions and their thresholds (`proposal.md`, section 12; `pilot-b/preregistration.md`, section 5), before reading the verdict as settled.

## D3. The amendment before the run

What: the optimism of a resample is read at each curve's chosen cutoff, $\bar J_b(\hat c_b) - \bar J(\hat c_b)$, and the corrected index starts from $\bar J(\hat c)$, not from the maximum. Why: the known-answer check of a reproducing bootstrap failed under the first definition, because the tie rule's cutoff need not attain the maximum when tied intervals lie apart. The amendment was committed before any run; the pass rule is unchanged. Check: the known-answer row in `pilot-b/results/known_answers.rds` and the columns `apparent` and `apparent_at_c_hat` in the replicates.

## D4. The normal imputation engine

What: Bayesian normal linear regression (`mice::mice.impute.norm()`) with $D$, $Z$, $D \times Z$, beside predictive mean matching. Alternatives: the nearest-neighbour engine of the first pilot. Why: the normal model is correctly specified for this design, so a band that fails with it fails for reasons of inference, while a band that fails only with predictive mean matching fails because of the imputations; the nearest-neighbour engine with one auxiliary does not propagate the models' uncertainty (first pilot, D5). Check: the known-answer rows on the normal imputation.

## D5. The grid

What: 41 thresholds between the 10% and 90% quantiles of the observed marker. Alternatives: a fixed range around $c^*$, which an analyst does not know. Why: it is computed from the data an analyst has. Consequence: missing values fall mostly at high marker values, so the grid's upper end moves down as the missing fraction grows; whether $c^*$ lies inside the grid is recorded per replicate (`c_star_in_grid` in `pilot-b/results/cell_summaries.rds`), and a near-optimal set cannot contain a $c^*$ outside the grid.

## D6. The variance split and the critical value of the bootstrap band

What: the pointwise variance of the 20-imputation estimate is the variance of the resample means minus the within-resample imputation variance over $M$ plus the same over $L$, floored at zero; the critical value standardizes each resample's deviation by the resample means' own standard deviation. Alternatives: no split (the band too wide by the imputation noise of $M = 2$); a critical value from the split standard errors. Why: the split targets the estimate actually reported, and the critical value uses the spread the resamples have. Check: the band's coverage in the null cells, where the split has nothing to remove.

## D7. The replicate count

What: 500 replicates per cell, as pre-registered; the timing run projected 7 minutes on three workers (`pilot-b/results/timing.rds`), far inside the hour. Alternatives: more replicates, which the pre-registration did not provide for. Check: the actual runtime in `pilot-b/results/run_info.rds`.

## What was not done

- The kernel estimator, 1,000 per group, impute-then-bootstrap, the nearest-neighbour engine, the number of resamples and imputations per resample as factors, and the application: all left to the full design (`project-spec.md`, section 4).
- A grid that does not depend on the observed values, which the flat cells show is needed.
- A target for the near-optimal set's length: the pass rule judged only whether the set contains $c^*$.
- More replicates: the run took 9 minutes, and the pre-registration fixed 500, so the base cell's coverage is judged with an MCSE of about 0.013.
