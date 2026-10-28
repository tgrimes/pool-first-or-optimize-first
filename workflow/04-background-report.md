# Stage 4: background report

## Purpose

Write the detailed companion to the settled manuscript: the literature its Introduction rests on, source by source, and every result it uses, proved step by step with a justification for each step, at a level a reader with graduate training in statistics and no familiarity with the topic can follow, or can see what to learn to follow. The report is also the first independent check of the manuscript: a proof that does not go through, or a source the Introduction should have cited, is an issue raised to the user, not a note buried in the report.

## Inputs

- The settled manuscript: `manuscript/manuscript.qmd` and `_supplement.qmd`, rendered; `manuscript/citations.csv` with its passages; `manuscript/references.bib`.
- The package in `R/` and `results/`, for the numerical checks.
- `templates/background-report.qmd` and `manuscript/manuscript-helpers.R` (the report reads `results/` through the same helpers).

## Preconditions

- `STATUS.md` says the manuscript is settled.
- Zotero is serving; every cited item has its full text attached (the Zotero check of stage 1 and the references step of stage 3 guarantee it; confirm with a ping).
- The log is `log/04-background-report.md`.

## Procedure

**1. The map.** List every citation in the Introduction, in order, with the paragraph it sits in and the claim it supports (from `citations.csv`). List every result the manuscript uses: each formula in Methods, each proposition or lemma in the supplement, and each closed form the simulation checks against. These two lists are the report's table of contents; nothing on them may be skipped.

**2. The literature, source by source.** For each source of the Introduction, in the Introduction's order and grouped by its paragraphs: the full citation; what the paper did (its question, data, method, and main finding, in the report's words); what it did not do, as it bears on the manuscript; the passage the manuscript's claim rests on, quoted briefly from the full text with its location; and how the manuscript uses it. Then, for each paragraph of the Introduction, a closing note: what the paragraph's claim rests on across its sources, and whether any source carries more or less weight than the manuscript gives it. Reading is from the full text in Zotero, not from the recorded passage alone; a passage that does not say what the manuscript says it says is an issue.

**3. The theory, result by result.** For each result: the statement, in the manuscript's notation; what a reader needs to know first, as a short list with pointers (a definition, a theorem, a technique, and where to read about it); the walkthrough, as numbered steps, each one line of mathematics with one line of justification (which definition, identity, assumption, or earlier step it uses, and why it applies), expanding every step the supplement compresses; the assumptions, each with where it is used and what fails without it; a numerical check that runs at render time from the package's functions or from `results/` (a special case with a known answer, a large-sample agreement, an identity checked on simulated data), with its outcome stated; and where the manuscript uses the result. A step that cannot be justified is an issue, written as such and not smoothed over.

**4. Issues.** Collect every issue found: a step that does not go through, a passage that does not support its claim, a source the Introduction should cite (found while reading the cited sources' own references or their citing literature, within the stage's search allowance: the cited sources and what they cite, no broader search), an inconsistency between Methods and the supplement, a notation clash. Write them to `background/issues.md` as a table (location in the manuscript, the issue, its severity, the proposed fix, where the report shows it). Severity: blocking (a claim does not hold), substantive (a claim needs a changed statement or a new source), editorial.

**5. Render and check.** Render `background/background.qmd` (self-contained HTML, the pilot report's style: table of contents, LaTeX, footnotes allowed for terms a reader may not know). Check by hand until a checker exists: every Introduction citation has its section; every result has its walkthrough and its numerical check chunk, and every check passed or its failure is an issue; every quoted passage was read in Zotero in this stage, with the date in the log; every number is computed; the writing rules hold. Make one revision pass (stage 3, step 4) on the report.

**Stop.** Return the report and `issues.md`. If `issues.md` has a blocking or substantive issue, say so first: the manuscript goes back to stage 3 for a revision round before anything else, and the report is updated after it.

## Outputs

- `background/background.qmd` and `background.html`.
- `background/issues.md`.
- `log/04-background-report.md`: the map, the sources read with dates, the checks run, decisions, time, process feedback.

## What to return at the stop

One message: the count of sources covered and results walked through; the issues by severity with the blocking ones quoted; the numerical checks that failed, if any; the paths; what the agent was unsure of.

## Lessons

(None yet. This stage has not been run.)
