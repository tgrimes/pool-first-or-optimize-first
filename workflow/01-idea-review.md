# Stage 1: idea review

## Purpose

Turn `idea.md`, in whatever state it is in, into a proposal the user can judge: is the idea new, does it fit the literature, is its theory sound, is there a usable dataset, and what would a pilot have to show. Everything the idea claims is verified; everything it lacks is supplied or marked. The deliverable is `proposal.md`.

## Inputs

- `idea.md`. It may hold a paragraph or a full plan with aims, a literature review, a derivation, and datasets. Nothing in it is taken as verified.
- `templates/proposal.md`, the form this stage fills.
- `workflow/journals/`, for the target journal.

## Preconditions

- Zotero is open with the connector serving (`workflow/rules.md`, section 2). This stage can run its searches without it, but the Zotero check after the stop needs it.
- Literature search tools are available: PubMed, bioRxiv and medRxiv, Consensus, and the browser (Google Scholar, GitHub, GEO, the Human Cell Atlas portal). Searching is allowed in this stage; every search is logged.
- `log/01-idea-review.md` is started at the first step and holds the inventory, the searches, the decisions, and the process feedback.

## Procedure

**1. Inventory the idea.** Read `idea.md`. In the log, write what it states for each of: the question, the procedure in question, the setting, the mechanism, the estimand, any claimed theory, the aims, the literature it cites, the datasets it names, the journal, and constraints. For each, say whether it is stated, implied, or absent. Do not fill a gap yet.

**2. The paper test.** Apply the seven steps of the critique template to the idea, each answered as far as the idea allows, with what is missing named:

1. A procedure in wide use: which, in which package, with what default, and how its output is read.
2. A setting it was not built for but is used in: the heterogeneity in question (means, variances, composition, group size, observations per subject, architecture, batch).
3. The estimand, stated as a functional of a specific distribution: what users believe the output estimates.
4. The target and the bias term: what the procedure converges to under the setting, and the difference from the estimand. Sketch it with the three algebraic tools (mixture algebra, projection algebra, the second-order expansion) where one applies; label the sketch as a sketch, and say what a full derivation would need.
5. Confirmation by simulation: the smallest design that would show the effect, with a null cell and a cell with a known answer.
6. A correction or a diagnostic, read off the formula, or "none yet".
7. The application: a confirmed dataset and the one thing it would show.

A "no" on step 3 or 4 is stated plainly; it is the most common reason an idea is not yet a project.

**3. Prior work and novelty.** Search for what has been done: the procedure's own papers and their critiques, the mechanism in other fields (measurement error, meta-analysis, psychometrics, mixed models are frequent homes), benchmarks that observed the artifact, and fixes that exist. Log every search: the source, the query, the date, and which hits were read. For each relevant source, record what it did and what it did not do, read from the abstract or the full text and not from a title. Then give one verdict with its reason: the mechanism is new; the artifact is known informally with no closed form and no fix; or the result is published, with the source. Say what the idea adds beyond the closest source. If the user's own prior work is named in `idea.md`, say how the idea relates to it. List every source the proposal will cite, with the full citation and the identifier as seen on the page, as items to add to Zotero.

**4. Theory check.** For each derivation, proof sketch, or claimed result in the idea: restate it, check each step, name the first step that does not hold or is not justified, and propose the numerical check (a simulation or a special case with a known answer) that would catch an error in it. For the suspected mechanism, give the first-order sketch from step 2 of the paper test, with its assumptions. Do not present a sketch as a result.

**5. Datasets.** Find open datasets that fit the setting: the groups the question needs, the sample sizes, the measurement type, and single-cell or spatial where the question allows. For each candidate, open the accession or portal and record what is deposited (samples by group, format, processing level, access conditions, size), with the date. Mark each `verified` (opened and matches), `verify` (named in the literature, not opened), or `unavailable`. Recommend one with a fallback, and say what the application would show on it.

**6. Feasibility and the pilot plan.** Write the first simulation: the design cells, the methods, the measures, the known-answer cells, and an estimate of runtime from what is known. Write the three pilot questions with pass criteria as numbers, decided before any run: does the effect exist; is it large enough to matter at realistic sizes; is there a fix or a diagnostic. Say what code and data already exist. This is the draft pre-registration that stage 2 carries into `pilot/preregistration.md`.

**7. Impact and fit.** The size of the user base and how often the output is read the vulnerable way; the plausible size of the artifact at realistic sizes, from the mechanism; whether a correction or only a diagnostic is in sight; and the fit with the two paper types (a critique of what a procedure estimates, or a constructive method). Propose a target journal and a fallback with the journal guide's worksheet.

**8. Write `proposal.md`** from the template, in the proposal's own words and not by copying `idea.md`. Every claim has a source or a `[TO CONFIRM: ...]` marker. Every decision that is the user's carries a marker. The last two sections are the open questions and the Zotero list. Make one revision pass for clarity (stage 3, step 4) before the stop.

**Stop 1.** Return `proposal.md` and the log. The user reviews it, answers the open questions, and adds the listed items to Zotero with their full text. Wait.

**9. The Zotero check.** When told the library is updated: look each cited source up by DOI and then by title; a source is available when the item is there, its record is complete enough to cite, and a PDF with full text is attached (a pre-1980 record or a book counts without one). Start `manuscript/citations.csv` with one row per source (key, Zotero item, grade `core` or `supporting`, the section of the proposal, why it is needed, the identifier, the passage that supports the claim, the date read). Report record faults with the value to enter. If any source is missing, **Stop 2** (at most twice): return the missing list grouped by what the user must do, and wait. Then rebuild the proposal's citations from the checklist keys and mark the proposal final in `STATUS.md`.

## Outputs

- `proposal.md`, final after the Zotero check.
- `log/01-idea-review.md`: the inventory, the paper test, every search, the datasets opened, the decisions (D-numbered), the time per step, and the process feedback.
- `manuscript/citations.csv` started.

## Checks before the stop

- Every source the proposal cites is either in Zotero or in the items-to-add list with an identifier the agent saw.
- Every dataset marked `verified` was opened in this stage, with the date and what was seen.
- Every search is logged with query, source, and date.
- The proposal states the estimand as a functional, or says plainly that it cannot yet.
- The pilot plan has pass criteria as numbers.
- No claim without a source or a marker; the writing rules of `rules.md` hold.

## What to return at the stop

One message: the verdict in a sentence; the path to `proposal.md` and the log; the novelty verdict with the closest source; the recommended dataset and its status; the pilot's pass criteria; the count of open questions; the Zotero list with its count; and what the agent was unsure of.

## Lessons

(None yet. Dated entries go here after each project, with the change made to this file.)
