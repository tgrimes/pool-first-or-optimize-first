# Stage 4: background report

## Purpose

Write the detailed companion to the final manuscript: the literature its Introduction rests on, source by source, and every result it uses, proved step by step with a justification for each step, at a level a reader with graduate training in statistics and no familiarity with the topic can follow, or can see what to learn to follow. The report is also the first independent check of the manuscript: a proof that does not go through, or a source the Introduction should have cited, is an issue raised to the user, not a note buried in the report.

## Inputs

- The manuscript: `manuscript/manuscript.qmd` with `_supplement.qmd`, and `manuscript/manuscript.html` rendered in final mode (stage 3, step 6); `manuscript/citations.csv` with its passages; `manuscript/references.bib`.
- The package in `R/` and `results/`, for the numerical checks.
- `templates/background-report.qmd` and `manuscript/manuscript-helpers.R` (the report reads `results/` through the same helpers).
- `workflow/rules.md`, in full.

## Preconditions

- `STATUS.md` says `3, final`. If the user asks for the report before the production run, it is written on the settled draft, its numbers carry the quick label, and it is rendered again after stage 3, step 6.
- Zotero is serving; every cited item has its full text attached (the Zotero check of stage 1 and the references step of stage 3 guarantee it; confirm with a ping).
- The log is `log/04-background-report.md`.

## Procedure

**1. The map.**

1. Set `STATUS.md` to `4, in progress`.
2. List every citation in the Introduction, in order, with the paragraph it sits in and the claim it supports (from `citations.csv`).
3. List every result the manuscript uses: each formula in Methods, each proposition or lemma in the supplementary note, and each closed form the simulation checks against.
4. These two lists are the report's table of contents, written in the log; nothing on them may be skipped.

**2. The literature, source by source.** For each source of the Introduction, in the Introduction's order and grouped by its paragraphs:

1. The full citation.
2. What the paper did: its question, data, method, and main finding, in the report's words.
3. What it did not do, as it bears on the manuscript.
4. The passage the manuscript's claim rests on, quoted briefly from the full text with its location. Reading is from the full text in Zotero, not from the recorded passage alone; a passage that does not say what the manuscript says it says is an issue.
5. How the manuscript uses it.
6. For each paragraph of the Introduction, a closing note: what the paragraph's claim rests on across its sources, and whether any source carries more or less weight than the manuscript gives it.

**3. The theory, result by result.** For each result:

1. The statement, in the manuscript's notation.
2. What a reader needs to know first, as a short list with pointers (a definition, a theorem, a technique, and where to read about it).
3. The walkthrough, as numbered steps, each one line of mathematics with one line of justification (which definition, identity, assumption, or earlier step it uses, and why it applies), expanding every step the supplementary note compresses.
4. The assumptions, each with where it is used and what fails without it.
5. A numerical check that runs at render time from the package's functions or from `results/` (a special case with a known answer, a large-sample agreement, an identity checked on simulated data), with its outcome stated.
6. Where the manuscript uses the result.
7. A step that cannot be justified is an issue, written as such and not smoothed over.

**4. Issues.**

1. Collect every issue found: a step that does not go through, a passage that does not support its claim, a source the Introduction should cite, an inconsistency between Methods and the supplementary note, a notation clash.
2. The search allowance for missing sources is the cited sources and what they cite, and no broader search; log what was opened.
3. Write them to `background/issues.md` as a table: location in the manuscript, the issue, its severity, the proposed fix, where the report shows it. Severity: blocking (a claim does not hold), substantive (a claim needs a changed statement or a new source), editorial.

**5. Render and check.**

1. Copy `templates/background-report.qmd` to `background/background.qmd`, fill it, and render it (self-contained HTML; table of contents; LaTeX; footnotes allowed for terms a reader may not know).
2. Check by hand, and record each check in the log: every Introduction citation has its section; every result has its walkthrough and its numerical check chunk, and every check passed or its failure is an issue; every quoted passage was read in Zotero in this stage, with the date; every number is computed; the writing rules of `rules.md`, section 4, hold.
3. Make one revision pass (`03-manuscript.md`, step 4) on the report, and render again.
4. Set `STATUS.md` to `4, report at stop`, write the stage record line naming `background/background.html`, and commit with the rendered report ("Stage 4, step 5: background report").

**Stop.** Return the report and `issues.md`. If `issues.md` has a blocking or substantive issue, say so first: the manuscript goes back to stage 3 for a revision round before anything else, and the report is updated and rendered again after it. When the user declares the report done, `STATUS.md` says `4, done`.

## Outputs

- `background/background.qmd` and `background.html`.
- `background/issues.md`.
- `log/04-background-report.md`: the map, the sources read with dates, the checks run, decisions, time, process feedback.

## Checks before the stop

- Every item of the map has its section in the report.
- Every numerical check chunk ran, and every failure is in `issues.md`.
- Every quoted passage has a read date in the log.
- The rendered page is committed and `STATUS.md` names it.

## What to return at the stop

One message: the count of sources covered and results walked through; the issues by severity with the blocking ones quoted; the numerical checks that failed, if any; the paths; what the agent was unsure of.

## Delegating this stage

A worker reads this file and `rules.md` in full, then the manuscript, its supplementary note, and `citations.csv`. The brief adds the decisions already taken and the time box. The literature part (step 2) and the theory part (step 3) may go to two workers, since they touch different sections of one report; the coordinator merges and renders. The worker returns the stop message above and nothing else; the coordinator opens the report and `issues.md` and runs the checks before relaying.

## Lessons

(None yet. This stage has not been run.)
